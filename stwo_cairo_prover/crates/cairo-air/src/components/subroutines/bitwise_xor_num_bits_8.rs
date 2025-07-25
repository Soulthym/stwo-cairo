use crate::components::prelude::*;

#[derive(Copy, Clone, Serialize, Deserialize, CairoSerialize, CairoDeserialize)]
pub struct BitwiseXorNumBits8 {}

impl BitwiseXorNumBits8 {
    #[allow(unused_parens)]
    #[allow(clippy::double_parens)]
    #[allow(non_snake_case)]
    #[allow(clippy::unused_unit)]
    #[allow(unused_variables)]
    #[allow(clippy::too_many_arguments)]
    pub fn evaluate<E: EvalAtRow>(
        [bitwise_xor_num_bits_8_input_limb_0, bitwise_xor_num_bits_8_input_limb_1]: [E::F; 2],
        xor_col0: E::F,
        verify_bitwise_xor_8_lookup_elements: &relations::VerifyBitwiseXor_8,
        eval: &mut E,
    ) -> E::F {
        eval.add_to_relation(RelationEntry::new(
            verify_bitwise_xor_8_lookup_elements,
            E::EF::one(),
            &[
                bitwise_xor_num_bits_8_input_limb_0.clone(),
                bitwise_xor_num_bits_8_input_limb_1.clone(),
                xor_col0.clone(),
            ],
        ));

        xor_col0.clone()
    }
}
