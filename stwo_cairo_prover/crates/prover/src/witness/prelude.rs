pub use std::iter::zip;
pub use std::simd::Simd;

pub use cairo_air::pedersen::const_columns::PedersenPoints;
pub use cairo_air::poseidon::const_columns::PoseidonRoundKeys;
pub use cairo_air::preprocessed::*;
pub(crate) use cairo_air::relations;
pub use num_traits::{One, Zero};
pub use rayon::prelude::*;
pub use stwo::core::fields::m31::M31;
pub use stwo::core::fields::FieldExpOps;
pub use stwo::core::poly::circle::CanonicCoset;
pub use stwo::prover::backend::simd::column::BaseColumn;
pub use stwo::prover::backend::simd::conversion::Unpack;
pub use stwo::prover::backend::simd::m31::{PackedM31, LOG_N_LANES, N_LANES};
pub use stwo::prover::backend::simd::qm31::PackedQM31;
pub use stwo::prover::backend::simd::SimdBackend;
pub use stwo::prover::backend::Column;
pub use stwo::prover::poly::circle::CircleEvaluation;
pub use stwo::prover::poly::BitReversedOrder;
pub use stwo_air_utils::trace::component_trace::ComponentTrace;
pub use stwo_air_utils_derive::{IterMut, ParIterMut, Uninitialized};
pub use stwo_cairo_common::prover_types::cpu::*;
pub use stwo_cairo_common::prover_types::simd::*;
pub use stwo_constraint_framework::{LogupTraceGenerator, Relation};

pub use crate::witness::fast_deduction::blake::{
    BlakeRound, PackedBlakeG, PackedBlakeRoundSigma, PackedTripleXor32,
};
pub use crate::witness::fast_deduction::pedersen::{PackedPartialEcMul, PackedPedersenPointsTable};
pub use crate::witness::fast_deduction::poseidon::{
    PackedCube252, PackedPoseidon3PartialRoundsChain, PackedPoseidonFullRoundChain,
    PackedPoseidonRoundKeys,
};
pub use crate::witness::utils::*;
