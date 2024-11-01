use aiken/collection/list
use bodega/types.{PSettingDatum, ProjectInfoDatum}
use cardano/address.{from_script}
use cardano/address/credential
use cardano/assets.{PolicyId, flatten}
use cardano/transaction.{InlineDatum, OutputReference, Transaction}
use cardano/value
use types/cip68

// mint cip68 nft, then send to project prediction address
// send the reference token to the project creator

// close project and burn nft 

pub type PATMintRedeemer {
  Create {
    out_ref: OutputReference,
    seed_idx: Int,
    protocol_setting_ref_idx: Int,
  }
  Delete
}

pub fn is_pos_info_datum_valid(d: ProjectInfoDatum) -> Bool {
  d.deadline > 0 && d.admin_fee > 0 && d.envelope_amount > 0
}

// CIP-68 1 nft for project, 1 nft for creator
validator project_authtoken_mp(
  pos_info_script_hash: ByteArray,
  psettings_nft_policy_id: ByteArray,
  psettings_nft_policy_tn: ByteArray,
) {
  mint(redeemer: PATMintRedeemer, policy_id: PolicyId, self: Transaction) {
    let Transaction { mint, outputs, inputs, reference_inputs, .. } = self
    when redeemer is {
      Create { out_ref, seed_idx, protocol_setting_ref_idx } -> {
        expect Some(ref_protocol_setting_input) =
          list.at(reference_inputs, protocol_setting_ref_idx)
        expect
          assets.quantity_of(
            ref_protocol_setting_input.output.value,
            psettings_nft_policy_id,
            psettings_nft_policy_tn,
          ) == 1
        expect InlineDatum(protocol_setting_inline_datum) =
          ref_protocol_setting_input.output.datum
        expect protocol_setting_datum: PSettingDatum =
          protocol_setting_inline_datum
        expect Some(seed_input) = list.at(inputs, seed_idx)
        expect out_ref == seed_input.output_reference
        let OutputReference { transaction_id, output_index } = out_ref
        let ref_tkn =
          value.unique_token_name(
            transaction_id,
            output_index,
            cip68.prefix_100,
            #"",
          )
        let user_tkn =
          value.unique_token_name(
            transaction_id,
            output_index,
            cip68.prefix_222,
            #"",
          )
        let ref_value = assets.from_asset(policy_id, ref_tkn, 1)
        let user_value = assets.from_asset(policy_id, user_tkn, 1)
        let merged_mint = assets.merge(ref_value, user_value)
        expect [ref_output, ..] = outputs
        let pos_addr = from_script(pos_info_script_hash)
        expect
          credential.compare(
            pos_addr.payment_credential,
            ref_output.address.payment_credential,
          ) == Equal
        expect InlineDatum(pos_inline_datum) = ref_output.datum
        expect pos_info_datum: ProjectInfoDatum = pos_inline_datum
        expect is_pos_info_datum_valid(pos_info_datum)
        expect assets.quantity_of(ref_output.value, policy_id, ref_tkn) == 1
        expect
          assets.quantity_of(
            ref_output.value,
            protocol_setting_datum.pledge_policy_id,
            protocol_setting_datum.pledge_token_name,
          ) >= protocol_setting_datum.pledge
        // token dust attack by project creator???
        expect merged_mint == mint
        expect list.length(flatten(ref_output.value)) <= 3
        True
      }
      Delete -> True
    }
  }

  else(_) {
    fail
  }
}
