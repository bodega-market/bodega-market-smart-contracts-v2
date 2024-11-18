use aiken/collection/list
use bodega/types.{
  PositionDatum, ProjectInfoDatum, ProjectPredictionDatum,
  ProjectPredictionParams,
}
use bodega/utils.{
  decimals, find_license_deadline, find_posix_time_range, multiplier,
}
use cardano/address
use cardano/assets
use cardano/transaction.{
  InlineDatum, Input, Output, OutputReference, Transaction,
}

pub type ProjectPredictionRedeemer {
  Apply {
    own_input_idx: Int,
    own_output_idx: Int,
    project_info_idx: Int,
    license_idx: Int,
    pos_indices: List<(Int, Int)>,
  }
  Reward {
    own_input_idx: Int,
    own_output_idx: Int,
    license_idx: Int,
    pos_indices: List<(Int, Int)>,
  }
  Update
  Refund {
    own_input_idx: Int,
    own_output_idx: Int,
    license_idx: Int,
    pos_indices: List<(Int, Int)>,
  }
}

validator project_prediction(params: ProjectPredictionParams) {
  spend(
    option_datum: Option<ProjectPredictionDatum>,
    redeemer: ProjectPredictionRedeemer,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    expect Some(datum) = option_datum
    let own_input_datum: ProjectPredictionDatum = datum
    when redeemer is {
      Apply {
        own_input_idx,
        own_output_idx,
        project_info_idx,
        license_idx,
        pos_indices,
      } -> {
        let Transaction {
          inputs,
          reference_inputs,
          outputs,
          validity_range,
          ..
        } = self
        expect Some(Input { output: Output { value: batcher_value, .. }, .. }) =
          list.at(inputs, license_idx)
        expect Some(project_info_ref_input) =
          list.at(reference_inputs, project_info_idx)
        expect
          assets.quantity_of(
            project_info_ref_input.output.value,
            params.project_info_nft.policy_id,
            params.project_info_nft.asset_name,
          ) == 1
        expect InlineDatum(project_info_inline_datum) =
          project_info_ref_input.output.datum
        expect project_info_datum: ProjectInfoDatum = project_info_inline_datum
        let license_deadline =
          find_license_deadline(
            project_info_datum.batcher_policy_id,
            batcher_value,
          )
        let (_start_valid_time_range, end_valid_time_range) =
          find_posix_time_range(validity_range)
        expect license_deadline >= end_valid_time_range
        expect Some(own_input) = list.at(inputs, own_input_idx)
        expect Some(own_output) = list.at(outputs, own_output_idx)
        expect own_input.output.address == own_output.address
        expect InlineDatum(own_output_inline_datum) = own_output.datum
        expect own_output_datum: ProjectPredictionDatum =
          own_output_inline_datum
        expect
          assets.quantity_of(
            own_input.output.value,
            params.project_prediction_nft.policy_id,
            params.project_prediction_nft.asset_name,
          ) == 1
        expect
          assets.quantity_of(
            own_output.value,
            params.project_prediction_nft.policy_id,
            params.project_prediction_nft.asset_name,
          ) == 1
        let (total_in_pos_values, total_fee) =
          list.foldl(
            pos_indices,
            (assets.zero, 0),
            fn(curr, acc) {
              let (in_idx, out_idx) = curr
              let (cur_val, cur_total_fee) = acc
              expect Some(in) = list.at(inputs, in_idx)
              expect Some(out) = list.at(outputs, out_idx)
              expect InlineDatum(pos_inline_datum) = in.output.datum
              expect pos_datum: PositionDatum = pos_inline_datum
              let user_address =
                address.from_verification_key(pos_datum.pos_user_pkh)
                  |> address.with_delegation_key(pos_datum.pos_user_stake_key)
              expect user_address == out.address
              expect
                list.has(project_info_datum.candidates, pos_datum.pos_candidate)
              let num_candidate_shares =
                assets.quantity_of(
                  in.output.value,
                  project_info_datum.share_policy_id,
                  pos_datum.pos_candidate,
                )
              expect
                [
                  (
                    assets.ada_policy_id,
                    assets.ada_asset_name,
                    project_info_datum.envelope_amount,
                  ),
                  (
                    project_info_datum.share_policy_id,
                    pos_datum.pos_candidate,
                    num_candidate_shares,
                  ),
                ] == assets.flatten(out.value)
              (
                assets.merge(cur_val, in.output.value),
                cur_total_fee + pos_datum.pos_amount * project_info_datum.admin_fee_percent * decimals / multiplier,
              )
            },
          )
        expect
          own_output_datum.total_fee >= own_input_datum.total_fee + total_fee
        let in_prediction_length = list.length(own_input_datum.predictions)
        expect in_prediction_length == list.length(own_output_datum.predictions)
        let zip_in_out =
          list.zip(own_input_datum.predictions, own_output_datum.predictions)
        expect in_prediction_length == list.length(zip_in_out)
        list.foldr(
          zip_in_out,
          True,
          fn(in_out: (Pair<ByteArray, Int>, Pair<ByteArray, Int>), acc) {
            let (Pair(in_cand, in_amount), Pair(out_cand, out_amount)) = in_out
            expect in_cand == out_cand
            let apply_amount =
              assets.quantity_of(
                total_in_pos_values,
                project_info_datum.share_policy_id,
                in_cand,
              )

            in_amount + apply_amount == out_amount && acc
          },
        )
      }
      Reward { .. } -> True
      Update -> True
      Refund { .. } -> True
    }
  }

  else(_) {
    fail
  }
}
