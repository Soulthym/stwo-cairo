use core::iter::{IntoIterator, Iterator};
use crate::circle::{CirclePoint, CirclePointIndexImpl, Coset, CosetImpl};
use crate::fields::m31::{M31, m31};
use crate::fields::qm31::{QM31, QM31Serde};
use crate::fields::{BaseField, SecureField};
use crate::poly::utils::{butterfly, fold};
use crate::utils::pow2;

/// A univariate polynomial defined on a [LineDomain].
#[derive(Debug, Drop, Clone)]
pub struct LinePoly {
    /// The coefficients of the polynomial stored in bit-reversed order.
    ///
    /// The coefficients are in a basis relating to the circle's x-coordinate doubling
    /// map `pi(x) = 2x^2 - 1` i.e.
    ///
    /// ```text
    /// B = { 1 } * { x } * { pi(x) } * { pi(pi(x)) } * ...
    ///   = { 1, x, pi(x), pi(x) * x, pi(pi(x)), pi(pi(x)) * x, pi(pi(x)) * pi(x), ... }
    /// ```
    pub coeffs: Array<SecureField>,
    /// The number of coefficients stored as `log2(len(coeffs))`.
    pub log_size: u32,
}

#[generate_trait]
pub impl LinePolyImpl of LinePolyTrait {
    /// Returns the number of coefficients.
    fn len(self: @LinePoly) -> usize {
        self.coeffs.len()
    }

    /// Evaluates the polynomial at a single point.
    // TODO(andrew): Can remove if only use `Self::evaluate()` in the verifier.
    // Note there are tradeoffs depending on the blowup factor last FRI layer degree bound.
    fn eval_at_point(self: @LinePoly, mut x: BaseField) -> SecureField {
        let mut doublings = array![];
        for _ in 0..*self.log_size {
            doublings.append(x);
            let x_square = x * x;
            x = x_square + x_square - m31(1);
        }

        fold(self.coeffs, @doublings, 0, 0, self.coeffs.len())
    }

    fn evaluate(self: @LinePoly, domain: LineDomain) -> LineEvaluation {
        assert!(domain.size() >= self.coeffs.len());

        // The first few FFT layers may just copy coefficients so we do it directly.
        // See the docs for `n_skipped_layers` in `line_fft()`.
        let log_domain_size = domain.log_size();
        let log_degree_bound = *self.log_size;
        let n_skipped_layers = log_domain_size - log_degree_bound;
        let duplicity = pow2(n_skipped_layers);
        let coeffs = repeat_value(self.coeffs.span(), duplicity);

        LineEvaluationImpl::new(domain, line_fft(coeffs, domain, n_skipped_layers))
    }
}

/// Repeats each value sequentially `duplicity` many times.
pub fn repeat_value(values: Span<QM31>, duplicity: usize) -> Array<QM31> {
    let mut res = array![];
    for v in values {
        for _ in 0..duplicity {
            res.append(*v)
        };
    }
    res
}

/// Performs a FFT on a univariate polynomial.
///
/// `values` is the coefficients stored in bit-reversed order. The evaluations of the polynomial
/// over `domain` is returned in natural order.
///
/// `n_skipped_layers` specifies how many of the initial butterfly layers to skip. This is used for
/// more efficient degree aware FFTs as the butterflies in the first layers of the FFT only involve
/// copying coefficients to different locations (because one or more of the coefficients is zero).
/// This new algorithm is `O(n log d)` vs `O(n log n)` where `n` is the domain size and `d` is the
/// degree of the polynomial.
///
/// Note the algorithm does not operate on coefficients in the standard monomial basis but rather
/// coefficients in a basis relating to the circle's x-coordinate doubling map `pi(x) = 2x^2 - 1`
/// i.e.
///
/// ```text
/// B = { 1 } * { x } * { pi(x) } * { pi(pi(x)) } * ...
///   = { 1, x, pi(x), pi(x) * x, pi(pi(x)), pi(pi(x)) * x, pi(pi(x)) * pi(x), ... }
/// ```
///
/// # Panics
///
/// Panics if the number of values doesn't match the size of the domain.
#[inline]
fn line_fft(
    mut values: Array<QM31>, mut domain: LineDomain, n_skipped_layers: usize,
) -> Array<QM31> {
    let n = values.len();
    assert!(values.len() == domain.size());

    let mut domains = array![];
    while domain.log_size() != n_skipped_layers {
        domains.append(domain);
        domain = domain.double();
    }
    let mut domains = domains.span();

    while let Some(domain) = domains.pop_back() {
        let chunk_size = domain.size();
        let twiddles = gen_twiddles(domain).span();
        let n_chunks = n / chunk_size;
        let stride = chunk_size / 2;
        let values_span = values.span();
        let mut next_values = array![];
        for chunk_i in 0..n_chunks {
            let chunk_offset = chunk_i * chunk_size;
            let mut chunk_l_vals = values_span.slice(chunk_offset, stride).into_iter();
            let mut chunk_r_vals = values_span.slice(chunk_offset + stride, stride).into_iter();
            let mut next_r_values = array![];
            for twiddle in twiddles {
                let v0 = *chunk_l_vals.next().unwrap();
                let v1 = *chunk_r_vals.next().unwrap();
                let (v0, v1) = butterfly(v0, v1, *twiddle);
                next_values.append(v0);
                next_r_values.append(v1);
            }
            next_values.append_span(next_r_values.span());
        }
        values = next_values;
    }

    values
}

#[inline]
fn gen_twiddles(self: @LineDomain) -> Array<M31> {
    let mut iter = LineDomainIterator {
        cur: self.coset.initial_index.to_point(),
        step: self.coset.step.to_point(),
        remaining: self.size() / 2,
    };
    let mut res = array![];
    while let Some(v) = iter.next() {
        res.append(v);
    }
    res
}

pub impl LinePolySerde of Serde<LinePoly> {
    fn serialize(self: @LinePoly, ref output: Array<felt252>) {
        self.coeffs.serialize(ref output);
        self.log_size.serialize(ref output);
    }

    fn deserialize(ref serialized: Span<felt252>) -> Option<LinePoly> {
        let res = LinePoly {
            coeffs: Serde::deserialize(ref serialized)?,
            log_size: Serde::deserialize(ref serialized)?,
        };

        // Check the sizes match.
        if res.coeffs.len() != pow2(res.log_size) {
            return None;
        }

        Some(res)
    }
}

/// Domain comprising of the x-coordinates of points in a [Coset].
///
/// For use with univariate polynomials.
#[derive(Copy, Drop, Debug)]
pub struct LineDomain {
    pub coset: Coset,
}

#[generate_trait]
pub impl LineDomainImpl of LineDomainTrait {
    /// Returns a domain comprising of the x-coordinates of points in a coset.
    ///
    /// # Safety
    ///
    /// All coset points must have unique `x` coordinates.
    fn new_unchecked(coset: Coset) -> LineDomain {
        LineDomain { coset: coset }
    }

    /// Returns the `i`th domain element.
    fn at(self: @LineDomain, index: usize) -> M31 {
        self.coset.at(index).x
    }

    /// Returns the size of the domain.
    fn size(self: @LineDomain) -> usize {
        self.coset.size()
    }

    /// Returns the log size of the domain.
    fn log_size(self: @LineDomain) -> usize {
        *self.coset.log_size
    }

    /// Returns a new domain comprising of all points in current domain doubled.
    fn double(self: @LineDomain) -> LineDomain {
        LineDomain { coset: self.coset.double() }
    }
}

/// Evaluations of a univariate polynomial on a [LineDomain].
#[derive(Drop)]
pub struct LineEvaluation {
    /// Evaluations in natural order.
    pub values: Array<QM31>,
    pub domain: LineDomain,
}

#[generate_trait]
pub impl LineEvaluationImpl of LineEvaluationTrait {
    /// Creates new [LineEvaluation] from a set of polynomial evaluations over a [LineDomain].
    fn new(domain: LineDomain, values: Array<QM31>) -> LineEvaluation {
        assert!(values.len() == domain.size());
        LineEvaluation { values: values, domain: domain }
    }
}

#[derive(Drop, Clone)]
pub(crate) struct LineDomainIterator {
    pub cur: CirclePoint<M31>,
    pub step: CirclePoint<M31>,
    pub remaining: usize,
}

impl LineDomainIteratorImpl of Iterator<LineDomainIterator> {
    type Item = M31;

    fn next(ref self: LineDomainIterator) -> Option<M31> {
        if self.remaining == 0 {
            return None;
        }
        self.remaining -= 1;
        let res = self.cur.x;
        self.cur = self.cur + self.step;
        Some(res)
    }
}
