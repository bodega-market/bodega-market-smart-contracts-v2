use aiken/collection/list
use bodega/types.{Asset, PositionDatum, ProjectInfoDatum}
use bodega/utils.{decimals, find_posix_time_range, multiplier}
use cardano/address.{Address, Script}
use cardano/assets.{PolicyId, flatten}
use cardano/transaction.{InlineDatum, Input, Output, Transaction}

pub type ShareRedeemer {
  Buy { project_info_ref_idx: Int }
  Reward { pred_in_idx: Int }
  Refund { pred_in_idx: Int }
}

pub type ShareParams {
  payment_asset: Asset,
  project_info_nft: Asset,
}

validator project_shares(params: ShareParams) {
  mint(redeemer: ShareRedeemer, policy_id: PolicyId, self: Transaction) {
    let Transaction {
      mint,
      inputs,
      reference_inputs,
      outputs,
      validity_range,
      ..
    } = self
    let flatten_mint = flatten(mint)
    when redeemer is {
      Buy { project_info_ref_idx } -> {
        expect Some(project_info_ref_input) =
          list.at(reference_inputs, project_info_ref_idx)
        expect
          assets.quantity_of(
            project_info_ref_input.output.value,
            params.project_info_nft.policy_id,
            params.project_info_nft.asset_name,
          ) == 1
        expect InlineDatum(project_info_output_datum) =
          project_info_ref_input.output.datum
        expect project_info_datum: ProjectInfoDatum = project_info_output_datum
        let (_start_valid_time_range, end_valid_time_range) =
          find_posix_time_range(validity_range)
        expect end_valid_time_range < project_info_datum.deadline
        let pos_script_cred = Script(project_info_datum.position_script_hash)
        let pos_outputs =
          list.filter(
            outputs,
            fn(output) {
              let Output { address: Address { payment_credential, .. }, .. } =
                output
              expect payment_credential == pos_script_cred
              expect InlineDatum(pos_output_datum) = output.datum
              expect pos_datum: PositionDatum = pos_output_datum
              expect pos_datum.pos_batcher_fee > 0 && pos_datum.pos_amount > 0
              let admin_fee_amount =
                pos_datum.pos_amount * project_info_datum.admin_fee_percent * decimals / multiplier
              let min_lovelace =
                pos_datum.pos_batcher_fee + project_info_datum.envelope_amount
              let min_payment =
                pos_datum.pos_amount * decimals + admin_fee_amount
              let out_pos_lovelace = assets.lovelace_of(output.value)
              if project_info_datum.payment_policy_id == assets.ada_policy_id {
                out_pos_lovelace >= min_payment + min_lovelace
              } else {
                out_pos_lovelace >= min_lovelace && assets.quantity_of(
                  output.value,
                  project_info_datum.payment_policy_id,
                  project_info_datum.payment_token_name,
                ) >= min_payment
              }
            },
          )
        expect [pos_output] = pos_outputs
        expect InlineDatum(pos_output_datum) = pos_output.datum
        expect pos_datum: PositionDatum = pos_output_datum
        expect
          assets.quantity_of(
            pos_output.value,
            policy_id,
            pos_datum.pos_candidate,
          ) == pos_datum.pos_amount
        [(policy_id, pos_datum.pos_candidate, pos_datum.pos_amount)] == flatten_mint
      }
      Reward { pred_in_idx } -> {
        expect Some(pred_input) = list.at(inputs, pred_in_idx)
        assets.quantity_of(
          pred_input.output.value,
          params.project_info_nft.policy_id,
          params.project_info_nft.asset_name,
        ) == 1
      }
      Refund { pred_in_idx } -> {
        expect Some(pred_input) = list.at(inputs, pred_in_idx)
        assets.quantity_of(
          pred_input.output.value,
          params.project_info_nft.policy_id,
          params.project_info_nft.asset_name,
        ) == 1
      }
    }
  }

  else(_) {
    fail
  }
}
