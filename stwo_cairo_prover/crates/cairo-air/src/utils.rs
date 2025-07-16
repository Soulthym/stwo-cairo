use std::fs::File;
use std::io::Write;
use std::path::PathBuf;

use bincode;
use serde::Serialize;
use stwo::core::channel::MerkleChannel;
use stwo::core::vcs::MerkleHasher;
use stwo_cairo_serialize::CairoSerialize;
use tracing::{span, Level};

use crate::CairoProof;

/// Cairo proof format
#[derive(Debug, Clone, clap::ValueEnum)]
pub enum ProofFormat {
    /// Standard JSON format.
    Json,
    /// Array of field elements serialized as hex strings.
    /// Compatible with `scarb execute`
    CairoSerde,
}
#[derive(Debug, Clone, Serialize)]
struct EncodedFieldElement(starknet_ff::FieldElement);
impl bincode::Encode for EncodedFieldElement {
    fn encode<E: bincode::enc::Encoder>(
        &self,
        encoder: &mut E,
    ) -> core::result::Result<(), bincode::error::EncodeError> {
        bincode::Encode::encode(&self.0.to_bytes_be(), encoder)?;
        Ok(())
    }
}

/// Serializes Cairo proof given the desired format and writes it to a file.

pub fn serialize_proof_to_file<MC: MerkleChannel>(
    proof: &CairoProof<MC::H>,
    proof_path: PathBuf,
    proof_format: ProofFormat,
) -> Result<(), std::io::Error>
where
    MC::H: Serialize,
    <MC::H as MerkleHasher>::Hash: CairoSerialize,
{
    let span = span!(Level::INFO, "Serialize proof").entered();

    let mut proof_file = File::create(proof_path)?;

    match proof_format {
        ProofFormat::Json => {
            proof_file.write_all(sonic_rs::to_string_pretty(proof)?.as_bytes())?;
        }
        ProofFormat::CairoSerde => {
            let mut serialized: Vec<starknet_ff::FieldElement> = Vec::new();
            CairoSerialize::serialize(proof, &mut serialized);
            let serialized: Vec<EncodedFieldElement> =
                serialized.into_iter().map(EncodedFieldElement).collect();
            let Ok(bin_serialized) =
                bincode::encode_to_vec(&serialized, bincode::config::standard())
            else {
                return Err(std::io::Error::new(
                    std::io::ErrorKind::InvalidData,
                    "Failed to serialize proof",
                ));
            };
            println!("Serialized proof size: {}", bin_serialized.len());
            proof_file.write_all(&bin_serialized)?;
            // let hex_strings: Vec<String> = serialized
            //     .into_iter()
            //     .map(|felt| format!("0x{:x}", felt))
            //     .collect();
            //
            // proof_file.write_all(sonic_rs::to_string_pretty(&hex_strings)?.as_bytes())?;
        }
    }

    span.exit();
    Ok(())
}
