use aiken/collection/dict
use aiken/collection/list
use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/primitive/string
use bodega/constants.{
  project_info_nft_tn, project_prediction_nft_tn, psetting_nft_tn,
}
use bodega/test_constants.{
  license_symbol, project_info_nft_policy_id, protocol_nft_policy_id,
  share_policy_id,
}
use bodega/types.{
  BuyPos, OracleDatum, PSettingDatum, PositionDatum, ProjectInfoDatum,
  ProjectPredictionDatum, RefundPos, RewardPos,
}
use bodega/utils.{
  decimals, find_license_deadline, find_posix_time_range, multiplier,
}
use cardano/address.{from_script}
use cardano/assets.{flatten}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}

pub type ProjectPredictionRedeemer {
  Apply {
    own_input_idx: Int,
    own_output_idx: Int,
    project_info_idx: Int,
    protocol_setting_ref_idx: Int,
    license_idx: Int,
    pos_indices: List<(Int, Int)>,
  }
  Reward {
    own_input_idx: Int,
    own_output_idx: Int,
    project_info_idx: Int,
    protocol_setting_ref_idx: Int,
    oracle_ref_input_idx: Int,
    license_idx: Int,
    pos_indices: List<(Int, Int)>,
  }
  Refund {
    own_input_idx: Int,
    own_output_idx: Int,
    project_info_idx: Int,
    protocol_setting_ref_idx: Int,
    license_idx: Int,
    pos_indices: List<(Int, Int)>,
  }
  WithdrawFee {
    own_input_idx: Int,
    own_output_idx: Int,
    project_info_idx: Int,
    protocol_setting_ref_idx: Int,
    license_idx: Int,
    treasury_out_idx: Int,
  }
}

validator project_prediction(
  psettings_nft_policy_id: ByteArray,
  psettings_nft_tn: ByteArray,
) {
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
        protocol_setting_ref_idx,
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
        expect Some(ref_protocol_setting_input) =
          list.at(reference_inputs, protocol_setting_ref_idx)
        expect
          assets.quantity_of(
            ref_protocol_setting_input.output.value,
            psettings_nft_policy_id,
            psettings_nft_tn,
          ) == 1
        expect InlineDatum(protocol_setting_inline_datum) =
          ref_protocol_setting_input.output.datum
        expect protocol_setting_datum: PSettingDatum =
          protocol_setting_inline_datum
        expect Some(Input { output: Output { value: batcher_value, .. }, .. }) =
          list.at(inputs, license_idx)
        expect Some(project_info_ref_input) =
          list.at(reference_inputs, project_info_idx)
        expect
          assets.quantity_of(
            project_info_ref_input.output.value,
            protocol_setting_datum.project_authtoken_policy_id,
            protocol_setting_datum.project_info_token_name,
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
            protocol_setting_datum.project_authtoken_policy_id,
            protocol_setting_datum.project_prediction_token_name,
          ) == 1
        expect
          assets.quantity_of(
            own_output.value,
            protocol_setting_datum.project_authtoken_policy_id,
            protocol_setting_datum.project_prediction_token_name,
          ) == 1
        let (total_in_pos_values, total_in_shares, total_fee) =
          list.foldl(
            pos_indices,
            (assets.zero, 0, 0),
            fn(curr, acc) {
              let (in_idx, out_idx) = curr
              let (cur_val, cur_shares, cur_total_fee) = acc
              expect Some(in) = list.at(inputs, in_idx)
              expect Some(out) = list.at(outputs, out_idx)
              expect InlineDatum(pos_inline_datum) = in.output.datum
              expect pos_datum: PositionDatum = pos_inline_datum
              expect pos_datum.outref_id == project_info_datum.outref_id
              expect pos_datum.pos_type == BuyPos
              let user_address =
                when pos_datum.pos_user_stake_key is {
                  Some(key) ->
                    address.from_verification_key(pos_datum.pos_user_pkh)
                      |> address.with_delegation_key(key)
                  None -> address.from_verification_key(pos_datum.pos_user_pkh)
                }
              expect user_address == out.address
              expect
                list.has(project_info_datum.candidates, pos_datum.pos_candidate)
              let num_candidate_shares =
                assets.quantity_of(
                  in.output.value,
                  project_info_datum.share_policy_id,
                  pos_datum.pos_candidate,
                )
              expect num_candidate_shares == pos_datum.pos_amount
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
                cur_shares + num_candidate_shares,
                cur_total_fee + pos_datum.pos_amount * project_info_datum.admin_fee_percent * decimals / multiplier,
              )
            },
          )
        let flatten_own_output_value = assets.flatten(own_output.value)
        let input_lovelace = assets.lovelace_of(own_input.output.value)
        let output_lovelace = assets.lovelace_of(own_output.value)
        when project_info_datum.payment_policy_id == assets.ada_policy_id is {
          True -> {
            expect list.length(flatten_own_output_value) == 2
            expect
              input_lovelace + total_in_shares * decimals + total_fee <= output_lovelace
          }
          False -> {
            let input_payment =
              assets.quantity_of(
                own_input.output.value,
                project_info_datum.payment_policy_id,
                project_info_datum.payment_token_name,
              )
            let output_payment =
              assets.quantity_of(
                own_output.value,
                project_info_datum.payment_policy_id,
                project_info_datum.payment_token_name,
              )
            expect list.length(flatten_own_output_value) <= 3
            expect
              input_payment + total_in_shares * decimals + total_fee <= output_payment
            expect input_lovelace <= output_lovelace
          }
        }
        expect own_input_datum.outref_id == own_output_datum.outref_id
        expect
          own_output_datum.total_fee == own_input_datum.total_fee + total_fee
        let in_prediction_length = list.length(own_input_datum.predictions)
        expect in_prediction_length == list.length(own_output_datum.predictions)
        let in_out_zip =
          list.zip(own_input_datum.predictions, own_output_datum.predictions)
        expect in_prediction_length == list.length(in_out_zip)
        list.foldr(
          in_out_zip,
          True,
          fn(in_out: ((ByteArray, Int), (ByteArray, Int)), acc) {
            let ((in_cand, in_amount), (out_cand, out_amount)) = in_out
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
      Reward {
        own_input_idx,
        own_output_idx,
        project_info_idx,
        protocol_setting_ref_idx,
        oracle_ref_input_idx,
        license_idx,
        pos_indices,
      } -> {
        let Transaction {
          inputs,
          reference_inputs,
          outputs,
          mint,
          validity_range,
          ..
        } = self
        expect Some(ref_protocol_setting_input) =
          list.at(reference_inputs, protocol_setting_ref_idx)
        expect
          assets.quantity_of(
            ref_protocol_setting_input.output.value,
            psettings_nft_policy_id,
            psettings_nft_tn,
          ) == 1
        expect InlineDatum(protocol_setting_inline_datum) =
          ref_protocol_setting_input.output.datum
        expect protocol_setting_datum: PSettingDatum =
          protocol_setting_inline_datum
        expect Some(Input { output: Output { value: batcher_value, .. }, .. }) =
          list.at(inputs, license_idx)
        expect Some(project_info_ref_input) =
          list.at(reference_inputs, project_info_idx)
        expect
          assets.quantity_of(
            project_info_ref_input.output.value,
            protocol_setting_datum.project_authtoken_policy_id,
            protocol_setting_datum.project_info_token_name,
          ) == 1
        expect InlineDatum(project_info_inline_datum) =
          project_info_ref_input.output.datum
        expect project_info_datum: ProjectInfoDatum = project_info_inline_datum
        expect Some(oracle_ref_input) =
          list.at(reference_inputs, oracle_ref_input_idx)
        expect
          assets.quantity_of(
            oracle_ref_input.output.value,
            project_info_datum.oracle_policy_id,
            project_info_datum.oracle_token_name,
          ) == 1
        expect InlineDatum(oracle_inline_datum) = oracle_ref_input.output.datum
        expect oracle_datum: OracleDatum = oracle_inline_datum
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
            protocol_setting_datum.project_authtoken_policy_id,
            protocol_setting_datum.project_prediction_token_name,
          ) == 1
        expect
          assets.quantity_of(
            own_output.value,
            protocol_setting_datum.project_authtoken_policy_id,
            protocol_setting_datum.project_prediction_token_name,
          ) == 1
        let (total_shares, win_shares) =
          list.foldr(
            own_input_datum.predictions,
            (0, 0),
            fn((cand, amount), acc) {
              let (cur_total_shares, cur_win_shares) = acc
              (
                cur_total_shares + amount,
                if oracle_datum.candidate == cand {
                  cur_win_shares + amount
                } else {
                  cur_win_shares
                },
              )
            },
          )
        let (total_in_pos_values, total_reward, total_in_shares, total_fee) =
          list.foldl(
            pos_indices,
            (assets.zero, 0, 0, 0),
            fn(curr, acc) {
              let (in_idx, out_idx) = curr
              let (cur_val, cur_reward, cur_num_shares, cur_total_fee) = acc
              expect Some(in) = list.at(inputs, in_idx)
              expect Some(out) = list.at(outputs, out_idx)
              expect InlineDatum(pos_inline_datum) = in.output.datum
              expect pos_datum: PositionDatum = pos_inline_datum
              expect pos_datum.outref_id == project_info_datum.outref_id
              expect pos_datum.pos_type == RewardPos
              let user_address =
                when pos_datum.pos_user_stake_key is {
                  Some(key) ->
                    address.from_verification_key(pos_datum.pos_user_pkh)
                      |> address.with_delegation_key(key)
                  None -> address.from_verification_key(pos_datum.pos_user_pkh)
                }
              expect user_address == out.address
              expect
                list.has(project_info_datum.candidates, pos_datum.pos_candidate)
              expect pos_datum.pos_candidate == oracle_datum.candidate
              let num_candidate_shares =
                assets.quantity_of(
                  in.output.value,
                  project_info_datum.share_policy_id,
                  pos_datum.pos_candidate,
                )
              let fee =
                pos_datum.pos_amount * project_info_datum.admin_fee_percent * decimals / multiplier
              let reward =
                num_candidate_shares * total_shares * decimals / win_shares
              if project_info_datum.payment_policy_id == assets.ada_policy_id {
                expect
                  [
                    (
                      assets.ada_policy_id,
                      assets.ada_asset_name,
                      project_info_datum.envelope_amount + reward,
                    ),
                  ] == assets.flatten(out.value)
              } else {
                expect
                  [
                    (
                      assets.ada_policy_id,
                      assets.ada_asset_name,
                      project_info_datum.envelope_amount,
                    ),
                    (
                      project_info_datum.payment_policy_id,
                      project_info_datum.payment_token_name,
                      reward,
                    ),
                  ] == assets.flatten(out.value)
              }
              (
                assets.merge(cur_val, in.output.value),
                cur_reward + reward,
                cur_num_shares + num_candidate_shares,
                cur_total_fee + fee,
              )
            },
          )
        expect own_input_datum.outref_id == own_output_datum.outref_id
        expect
          own_input_datum.total_fee + total_fee == own_output_datum.total_fee
        let flatten_own_output_value = assets.flatten(own_output.value)
        let input_lovelace = assets.lovelace_of(own_input.output.value)
        let output_lovelace = assets.lovelace_of(own_output.value)
        if project_info_datum.payment_policy_id == assets.ada_policy_id {
          expect list.length(flatten_own_output_value) == 2
          expect input_lovelace + total_fee == output_lovelace + total_reward
        } else {
          expect list.length(flatten_own_output_value) <= 3
          expect input_lovelace == output_lovelace
          let input_payment =
            assets.quantity_of(
              own_input.output.value,
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
            )
          let output_payment =
            assets.quantity_of(
              own_output.value,
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
            )
          expect input_payment + total_fee == output_payment + total_reward
        }
        expect
          assets.quantity_of(
            total_in_pos_values,
            project_info_datum.share_policy_id,
            oracle_datum.candidate,
          ) == total_in_shares
        expect
          [
            (
              project_info_datum.share_policy_id,
              oracle_datum.candidate,
              -total_in_shares,
            ),
          ] == flatten(mint)
        let in_prediction_length = list.length(own_input_datum.predictions)
        expect in_prediction_length == list.length(own_output_datum.predictions)
        let in_out_zip =
          list.zip(own_input_datum.predictions, own_output_datum.predictions)
        expect in_prediction_length == list.length(in_out_zip)
        list.foldr(
          in_out_zip,
          True,
          fn(in_out: ((ByteArray, Int), (ByteArray, Int)), acc) {
            let ((in_cand, in_amount), (out_cand, out_amount)) = in_out
            expect in_cand == out_cand
            if in_cand == oracle_datum.candidate {
              in_amount == out_amount + total_in_shares && acc
            } else {
              in_amount == out_amount && acc
            }
          },
        )
      }

      Refund {
        own_input_idx,
        own_output_idx,
        project_info_idx,
        protocol_setting_ref_idx,
        license_idx,
        pos_indices,
      } -> {
        let Transaction {
          inputs,
          reference_inputs,
          outputs,
          mint,
          validity_range,
          ..
        } = self
        expect Some(ref_protocol_setting_input) =
          list.at(reference_inputs, protocol_setting_ref_idx)
        expect
          assets.quantity_of(
            ref_protocol_setting_input.output.value,
            psettings_nft_policy_id,
            psettings_nft_tn,
          ) == 1
        expect InlineDatum(protocol_setting_inline_datum) =
          ref_protocol_setting_input.output.datum
        expect protocol_setting_datum: PSettingDatum =
          protocol_setting_inline_datum
        expect Some(Input { output: Output { value: batcher_value, .. }, .. }) =
          list.at(inputs, license_idx)
        expect Some(project_info_ref_input) =
          list.at(reference_inputs, project_info_idx)
        expect
          assets.quantity_of(
            project_info_ref_input.output.value,
            protocol_setting_datum.project_authtoken_policy_id,
            protocol_setting_datum.project_info_token_name,
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
            protocol_setting_datum.project_authtoken_policy_id,
            protocol_setting_datum.project_prediction_token_name,
          ) == 1
        expect
          assets.quantity_of(
            own_output.value,
            protocol_setting_datum.project_authtoken_policy_id,
            protocol_setting_datum.project_prediction_token_name,
          ) == 1
        let (
          total_in_pos_values,
          total_refund,
          total_pos_count_shares,
          total_fee,
        ) =
          list.foldl(
            pos_indices,
            (assets.zero, 0, 0, 0),
            fn(curr, acc) {
              let (in_idx, out_idx) = curr
              let (cur_val, cur_refund, cur_num_shares, cur_total_fee) = acc
              expect Some(in) = list.at(inputs, in_idx)
              expect Some(out) = list.at(outputs, out_idx)
              expect InlineDatum(pos_inline_datum) = in.output.datum
              expect pos_datum: PositionDatum = pos_inline_datum
              expect pos_datum.outref_id == project_info_datum.outref_id
              let user_address =
                when pos_datum.pos_user_stake_key is {
                  Some(key) ->
                    address.from_verification_key(pos_datum.pos_user_pkh)
                      |> address.with_delegation_key(key)
                  None -> address.from_verification_key(pos_datum.pos_user_pkh)
                }
              expect user_address == out.address
              expect
                list.has(project_info_datum.candidates, pos_datum.pos_candidate)
              let num_candidate_shares =
                assets.quantity_of(
                  in.output.value,
                  project_info_datum.share_policy_id,
                  pos_datum.pos_candidate,
                )
              let fee =
                pos_datum.pos_amount * project_info_datum.admin_fee_percent * decimals / multiplier
              let refund = num_candidate_shares * decimals
              if project_info_datum.payment_policy_id == assets.ada_policy_id {
                expect
                  [
                    (
                      assets.ada_policy_id,
                      assets.ada_asset_name,
                      project_info_datum.envelope_amount + refund,
                    ),
                  ] == assets.flatten(out.value)
              } else {
                expect
                  [
                    (
                      assets.ada_policy_id,
                      assets.ada_asset_name,
                      project_info_datum.envelope_amount,
                    ),
                    (
                      project_info_datum.payment_policy_id,
                      project_info_datum.payment_token_name,
                      refund,
                    ),
                  ] == assets.flatten(out.value)
              }
              (
                assets.merge(cur_val, in.output.value),
                cur_refund + refund,
                cur_num_shares + num_candidate_shares,
                cur_total_fee + fee,
              )
            },
          )
        expect own_input_datum.outref_id == own_output_datum.outref_id
        expect
          own_input_datum.total_fee + total_fee == own_output_datum.total_fee
        let flatten_own_output_value = assets.flatten(own_output.value)
        let input_lovelace = assets.lovelace_of(own_input.output.value)
        let output_lovelace = assets.lovelace_of(own_output.value)
        if project_info_datum.payment_policy_id == assets.ada_policy_id {
          expect list.length(flatten_own_output_value) == 2
          expect input_lovelace + total_fee == output_lovelace + total_refund
        } else {
          expect list.length(flatten_own_output_value) <= 3
          expect input_lovelace == output_lovelace
          let input_payment =
            assets.quantity_of(
              own_input.output.value,
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
            )
          let output_payment =
            assets.quantity_of(
              own_output.value,
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
            )
          expect input_payment + total_fee == output_payment + total_refund
        }
        let (total_input_shares, expected_mint) =
          list.foldr(
            project_info_datum.candidates,
            (0, assets.zero),
            fn(cand, acc) {
              let (cur_shares, cur_mint) = acc
              let amt =
                assets.quantity_of(
                  total_in_pos_values,
                  project_info_datum.share_policy_id,
                  cand,
                )
              let in_amt =
                when
                  list.find(
                    own_input_datum.predictions,
                    fn((candidate, _amt)) { cand == candidate },
                  )
                is {
                  Some(x) -> {
                    let (_cand, amt) = x
                    amt
                  }
                  None -> fail @"invalid position"
                }
              let out_amt =
                when
                  list.find(
                    own_output_datum.predictions,
                    fn((candidate, _amt)) { cand == candidate },
                  )
                is {
                  Some(x) -> {
                    let (_cand, amt) = x
                    amt
                  }
                  None -> fail @"invalid position"
                }
              if amt >= 0 {
                expect in_amt == out_amt + amt
                (
                  cur_shares + amt,
                  assets.add(
                    cur_mint,
                    project_info_datum.share_policy_id,
                    cand,
                    -amt,
                  ),
                )
              } else {
                expect in_amt == out_amt
                (cur_shares, cur_mint)
              }
            },
          )
        expect total_input_shares == total_pos_count_shares
        expected_mint == mint
      }
      WithdrawFee {
        own_input_idx,
        own_output_idx,
        project_info_idx,
        protocol_setting_ref_idx,
        license_idx,
        treasury_out_idx,
      } -> {
        let Transaction {
          inputs,
          reference_inputs,
          outputs,
          validity_range,
          ..
        } = self
        expect Some(ref_protocol_setting_input) =
          list.at(reference_inputs, protocol_setting_ref_idx)
        expect
          assets.quantity_of(
            ref_protocol_setting_input.output.value,
            psettings_nft_policy_id,
            psettings_nft_tn,
          ) == 1
        expect InlineDatum(protocol_setting_inline_datum) =
          ref_protocol_setting_input.output.datum
        expect protocol_setting_datum: PSettingDatum =
          protocol_setting_inline_datum
        expect Some(own_input) = list.at(inputs, own_input_idx)
        expect Some(own_output) = list.at(outputs, own_output_idx)
        expect Some(Input { output: Output { value: batcher_value, .. }, .. }) =
          list.at(inputs, license_idx)
        expect Some(project_info_ref_input) =
          list.at(reference_inputs, project_info_idx)
        expect
          assets.quantity_of(
            project_info_ref_input.output.value,
            protocol_setting_datum.project_authtoken_policy_id,
            protocol_setting_datum.project_info_token_name,
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
        expect InlineDatum(own_output_inline_datum) = own_output.datum
        expect own_output_datum: ProjectPredictionDatum =
          own_output_inline_datum
        expect
          assets.quantity_of(
            own_input.output.value,
            protocol_setting_datum.project_authtoken_policy_id,
            protocol_setting_datum.project_prediction_token_name,
          ) == 1
        expect
          assets.quantity_of(
            own_output.value,
            protocol_setting_datum.project_authtoken_policy_id,
            protocol_setting_datum.project_prediction_token_name,
          ) == 1
        expect Some(Output {
          address: treasury_address,
          value: treasury_value,
          ..
        }) = list.at(outputs, treasury_out_idx)
        expect
          from_script(protocol_setting_datum.protocol_treasury_script_hash) == treasury_address
        let flatten_own_output_value = assets.flatten(own_output.value)
        expect list.length(flatten_own_output_value) <= 3
        let input_payment =
          assets.quantity_of(
            own_input.output.value,
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
          )
        let output_payment =
          assets.quantity_of(
            own_output.value,
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
          )
        let input_lovelace = assets.lovelace_of(own_input.output.value)
        let output_lovelace = assets.lovelace_of(own_output.value)
        when project_info_datum.payment_policy_id == assets.ada_policy_id is {
          True -> {
            expect
              assets.lovelace_of(treasury_value) >= own_input_datum.total_fee
            expect input_lovelace <= output_lovelace + own_input_datum.total_fee
          }
          False -> {
            expect input_payment == output_payment + own_input_datum.total_fee
          }
        }
        expect own_input_datum.outref_id == own_output_datum.outref_id
        expect own_input_datum.predictions == own_output_datum.predictions
        own_output_datum.total_fee == 0
      }
    }
  }

  else(_) {
    fail
  }
}

test predictions__spend_apply() {
  let project_info_script_hash =
    #"8db00d760acf62c0ebaa5ff2c36e9eeb9655d06c0a2f02d9e200aa6f"
  let project_prediction_script_hash =
    #"9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9eeb"
  let protocol_stake_key_hash =
    #"eb9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9e"
  let psetting_datum =
    PSettingDatum {
      pledge: 100_000_000,
      pledge_policy_id: #"",
      pledge_token_name: #"",
      protocol_treasury_script_hash: #"b4971034feee",
      share_ratio: 20000,
      open_fee: 20_000_000,
      open_fee_policy_id: #"",
      open_fee_token_name: #"",
      project_authtoken_policy_id: project_info_nft_policy_id,
      project_info_token_name: project_info_nft_tn,
      project_prediction_token_name: project_prediction_nft_tn,
      protocol_stake_key_hash,
    }
  let psetting_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let psetting_ref_input =
    Input {
      output_reference: psetting_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(protocol_nft_policy_id, psetting_nft_tn, 1),
        datum: InlineDatum(psetting_datum),
        reference_script: None,
      },
    }
  let project_info_ref_id =
    OutputReference {
      transaction_id: #"d07f157faf99b850b4971034feee28",
      output_index: 0,
    }
  let project_info_datum =
    ProjectInfoDatum {
      outref_id: project_info_ref_id,
      owner_pkh: #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      project_name: "test",
      deadline: 123_456,
      payment_policy_id: #"3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe",
      payment_token_name: "token_name",
      batcher_policy_id: #"6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e",
      position_script_hash: #"702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86",
      share_policy_id: #"2d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c425",
      oracle_policy_id: #"f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9",
      oracle_token_name: "oracle_token_name",
      admin_fee_percent: 500,
      // ^ base 10_000
      envelope_amount: 2_000_000,
      candidates: ["cand_1", "cand_2"],
    }
  let project_info_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let project_info_input =
    Input {
      output_reference: project_info_ref,
      output: Output {
        address: from_script(project_info_script_hash)
          |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
        value: assets.zero
          |> assets.add(
              psetting_datum.project_authtoken_policy_id,
              psetting_datum.project_info_token_name,
              1,
            ),
        datum: InlineDatum(project_info_datum),
        reference_script: None,
      },
    }
  let pred_datum =
    ProjectPredictionDatum {
      outref_id: project_info_ref_id,
      total_fee: 0,
      predictions: [("cand_1", 0), ("cand_2", 0)],
    }
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let pred_input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(project_prediction_script_hash)
          |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
        value: assets.from_lovelace(2_000_000)
          |> assets.add(
              psetting_datum.project_authtoken_policy_id,
              psetting_datum.project_prediction_token_name,
              1,
            ),
        datum: InlineDatum(pred_datum),
        reference_script: None,
      },
    }
  let amount = 10
  let fee = 10 * project_info_datum.admin_fee_percent * decimals / multiplier
  let pred_out_datum =
    ProjectPredictionDatum {
      outref_id: project_info_ref_id,
      total_fee: pred_datum.total_fee + fee,
      predictions: [("cand_1", 10), ("cand_2", 0)],
    }
  let pred_out =
    Output {
      address: from_script(project_prediction_script_hash)
        |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
      value: assets.from_lovelace(2_000_000)
        |> assets.add(
            psetting_datum.project_authtoken_policy_id,
            psetting_datum.project_prediction_token_name,
            1,
          )
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            amount * decimals,
          )
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            fee,
          ),
      datum: InlineDatum(pred_out_datum),
      reference_script: None,
    }
  let pos_datum =
    PositionDatum {
      outref_id: project_info_ref_id,
      pos_user_pkh: #"6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b",
      pos_user_stake_key: Some(
        #"c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3",
      ),
      pos_type: BuyPos,
      pos_amount: amount,
      pos_batcher_fee: 30_000,
      pos_candidate: "cand_1",
    }
  let pos_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let pos_input =
    Input {
      output_reference: pos_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(share_policy_id, pos_datum.pos_candidate, 10)
          |> assets.add(
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
              10 * decimals,
            ),
        datum: InlineDatum(pos_datum),
        reference_script: None,
      },
    }
  let user_address =
    when pos_datum.pos_user_stake_key is {
      Some(key) ->
        address.from_verification_key(pos_datum.pos_user_pkh)
          |> address.with_delegation_key(key)
      None -> address.from_verification_key(pos_datum.pos_user_pkh)
    }
  let user_pos_out =
    Output {
      address: user_address,
      value: assets.from_lovelace(2_000_000)
        |> assets.add(share_policy_id, pos_datum.pos_candidate, amount),
      datum: InlineDatum(pos_datum),
      reference_script: None,
    }
  let license_input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"07f157faf99b850b4971034feee28d",
        output_index: 0,
      },
      output: Output {
        address: from_script(#"12"),
        value: assets.add(
          assets.zero,
          license_symbol,
          string.to_bytearray(@"1727715600000"),
          1,
        ),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let license_output =
    Output {
      address: from_script(#"12"),
      value: assets.add(
        assets.zero,
        license_symbol,
        string.to_bytearray(@"1727715600000"),
        1,
      ),
      datum: NoDatum,
      reference_script: None,
    }
  let tx =
    Transaction {
      inputs: [pred_input, pos_input, license_input],
      reference_inputs: [project_info_input, psetting_ref_input],
      outputs: [pred_out, user_pos_out, license_output],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let pred_redeemer =
    Apply {
      own_input_idx: 0,
      own_output_idx: 0,
      project_info_idx: 0,
      protocol_setting_ref_idx: 1,
      license_idx: 2,
      pos_indices: [(1, 1)],
    }
  project_prediction.spend(
    protocol_nft_policy_id,
    psetting_nft_tn,
    Some(pred_datum),
    pred_redeemer,
    own_ref,
    tx,
  )
}

test predictions__spend_apply__ada() {
  let project_info_script_hash =
    #"8db00d760acf62c0ebaa5ff2c36e9eeb9655d06c0a2f02d9e200aa6f"
  let project_prediction_script_hash =
    #"9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9eeb"
  let protocol_stake_key_hash =
    #"eb9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9e"
  let psetting_datum =
    PSettingDatum {
      pledge: 100_000_000,
      pledge_policy_id: #"",
      pledge_token_name: #"",
      protocol_treasury_script_hash: #"b4971034feee",
      share_ratio: 20000,
      open_fee: 20_000_000,
      open_fee_policy_id: #"",
      open_fee_token_name: #"",
      project_authtoken_policy_id: project_info_nft_policy_id,
      project_info_token_name: project_info_nft_tn,
      project_prediction_token_name: project_prediction_nft_tn,
      protocol_stake_key_hash,
    }
  let psetting_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let psetting_ref_input =
    Input {
      output_reference: psetting_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(protocol_nft_policy_id, psetting_nft_tn, 1),
        datum: InlineDatum(psetting_datum),
        reference_script: None,
      },
    }
  let project_info_ref_id =
    OutputReference {
      transaction_id: #"d07f157faf99b850b4971034feee28",
      output_index: 0,
    }
  let project_info_datum =
    ProjectInfoDatum {
      outref_id: project_info_ref_id,
      owner_pkh: #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      project_name: "test",
      deadline: 123_456,
      payment_policy_id: #"",
      payment_token_name: "",
      batcher_policy_id: #"6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e",
      position_script_hash: #"702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86",
      share_policy_id: #"2d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c425",
      oracle_policy_id: #"f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9",
      oracle_token_name: "oracle_token_name",
      admin_fee_percent: 500,
      // ^ base 10_000
      envelope_amount: 2_000_000,
      candidates: ["cand_1", "cand_2"],
    }
  let project_info_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let project_info_input =
    Input {
      output_reference: project_info_ref,
      output: Output {
        address: from_script(project_info_script_hash)
          |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
        value: assets.zero
          |> assets.add(
              psetting_datum.project_authtoken_policy_id,
              psetting_datum.project_info_token_name,
              1,
            ),
        datum: InlineDatum(project_info_datum),
        reference_script: None,
      },
    }
  let pred_datum =
    ProjectPredictionDatum {
      outref_id: project_info_ref_id,
      total_fee: 0,
      predictions: [("cand_1", 0), ("cand_2", 0)],
    }
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let pred_input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(project_prediction_script_hash)
          |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
        value: assets.from_lovelace(2_000_000)
          |> assets.add(
              psetting_datum.project_authtoken_policy_id,
              psetting_datum.project_prediction_token_name,
              1,
            ),
        datum: InlineDatum(pred_datum),
        reference_script: None,
      },
    }
  let amount = 10
  let fee = 10 * project_info_datum.admin_fee_percent * decimals / multiplier
  let pred_out_datum =
    ProjectPredictionDatum {
      outref_id: project_info_ref_id,
      total_fee: pred_datum.total_fee + fee,
      predictions: [("cand_1", 10), ("cand_2", 0)],
    }
  let pred_out =
    Output {
      address: from_script(project_prediction_script_hash)
        |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
      value: assets.from_lovelace(2_000_000)
        |> assets.add(
            psetting_datum.project_authtoken_policy_id,
            psetting_datum.project_prediction_token_name,
            1,
          )
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            amount * decimals,
          )
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            fee,
          ),
      datum: InlineDatum(pred_out_datum),
      reference_script: None,
    }
  let pos_datum =
    PositionDatum {
      outref_id: project_info_ref_id,
      pos_user_pkh: #"6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b",
      pos_user_stake_key: Some(
        #"c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3",
      ),
      pos_type: BuyPos,
      pos_amount: amount,
      pos_batcher_fee: 30_000,
      pos_candidate: "cand_1",
    }
  let pos_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let pos_input =
    Input {
      output_reference: pos_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(share_policy_id, pos_datum.pos_candidate, 10)
          |> assets.add(
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
              10 * decimals,
            ),
        datum: InlineDatum(pos_datum),
        reference_script: None,
      },
    }
  let user_address =
    when pos_datum.pos_user_stake_key is {
      Some(key) ->
        address.from_verification_key(pos_datum.pos_user_pkh)
          |> address.with_delegation_key(key)
      None -> address.from_verification_key(pos_datum.pos_user_pkh)
    }
  let user_pos_out =
    Output {
      address: user_address,
      value: assets.from_lovelace(2_000_000)
        |> assets.add(share_policy_id, pos_datum.pos_candidate, amount),
      datum: InlineDatum(pos_datum),
      reference_script: None,
    }
  let license_input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"07f157faf99b850b4971034feee28d",
        output_index: 0,
      },
      output: Output {
        address: from_script(#"12"),
        value: assets.add(
          assets.zero,
          license_symbol,
          string.to_bytearray(@"1727715600000"),
          1,
        ),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let license_output =
    Output {
      address: from_script(#"12"),
      value: assets.add(
        assets.zero,
        license_symbol,
        string.to_bytearray(@"1727715600000"),
        1,
      ),
      datum: NoDatum,
      reference_script: None,
    }
  let tx =
    Transaction {
      inputs: [pred_input, pos_input, license_input],
      reference_inputs: [project_info_input, psetting_ref_input],
      outputs: [pred_out, user_pos_out, license_output],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let pred_redeemer =
    Apply {
      own_input_idx: 0,
      own_output_idx: 0,
      project_info_idx: 0,
      protocol_setting_ref_idx: 1,
      license_idx: 2,
      pos_indices: [(1, 1)],
    }
  project_prediction.spend(
    protocol_nft_policy_id,
    psetting_nft_tn,
    Some(pred_datum),
    pred_redeemer,
    own_ref,
    tx,
  )
}

test predictions__spend_reward() {
  let project_info_script_hash =
    #"8db00d760acf62c0ebaa5ff2c36e9eeb9655d06c0a2f02d9e200aa6f"
  let project_prediction_script_hash =
    #"9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9eeb"
  let protocol_stake_key_hash =
    #"eb9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9e"
  let psetting_datum =
    PSettingDatum {
      pledge: 100_000_000,
      pledge_policy_id: #"",
      pledge_token_name: #"",
      protocol_treasury_script_hash: #"b4971034feee",
      share_ratio: 20000,
      open_fee: 20_000_000,
      open_fee_policy_id: #"",
      open_fee_token_name: #"",
      project_authtoken_policy_id: project_info_nft_policy_id,
      project_info_token_name: project_info_nft_tn,
      project_prediction_token_name: project_prediction_nft_tn,
      protocol_stake_key_hash,
    }
  let psetting_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let psetting_ref_input =
    Input {
      output_reference: psetting_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(protocol_nft_policy_id, psetting_nft_tn, 1),
        datum: InlineDatum(psetting_datum),
        reference_script: None,
      },
    }
  let project_info_ref_id =
    OutputReference {
      transaction_id: #"d07f157faf99b850b4971034feee28",
      output_index: 0,
    }
  let project_info_datum =
    ProjectInfoDatum {
      outref_id: project_info_ref_id,
      owner_pkh: #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      project_name: "test",
      deadline: 123_456,
      payment_policy_id: #"3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe",
      payment_token_name: "token_name",
      batcher_policy_id: #"6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e",
      position_script_hash: #"702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86",
      share_policy_id: #"2d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c425",
      oracle_policy_id: #"f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9",
      oracle_token_name: "oracle_token_name",
      admin_fee_percent: 500,
      // ^ base 10_000
      envelope_amount: 2_000_000,
      candidates: ["cand_1", "cand_2"],
    }
  let project_info_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let project_info_input =
    Input {
      output_reference: project_info_ref,
      output: Output {
        address: from_script(project_info_script_hash)
          |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
        value: assets.zero
          |> assets.add(
              psetting_datum.project_authtoken_policy_id,
              psetting_datum.project_info_token_name,
              1,
            ),
        datum: InlineDatum(project_info_datum),
        reference_script: None,
      },
    }
  let pred_datum =
    ProjectPredictionDatum {
      outref_id: project_info_ref_id,
      total_fee: 0,
      predictions: [("cand_1", 100), ("cand_2", 400)],
    }
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let pred_input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(project_prediction_script_hash)
          |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
        value: assets.from_lovelace(2_000_000)
          |> assets.add(
              psetting_datum.project_authtoken_policy_id,
              psetting_datum.project_prediction_token_name,
              1,
            )
          |> assets.add(
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
              525 * decimals,
            ),
        datum: InlineDatum(pred_datum),
        reference_script: None,
      },
    }
  let amount = 10
  let fee = 10 * project_info_datum.admin_fee_percent * decimals / multiplier
  let pred_out_datum =
    ProjectPredictionDatum {
      outref_id: project_info_ref_id,
      total_fee: pred_datum.total_fee + fee,
      predictions: [("cand_1", 90), ("cand_2", 400)],
    }
  let pred_out =
    Output {
      address: from_script(project_prediction_script_hash)
        |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
      value: assets.from_lovelace(2_000_000)
        |> assets.add(
            psetting_datum.project_authtoken_policy_id,
            psetting_datum.project_prediction_token_name,
            1,
          )
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            475 * decimals,
          )
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            fee,
          ),
      datum: InlineDatum(pred_out_datum),
      reference_script: None,
    }
  let pos_datum =
    PositionDatum {
      outref_id: project_info_ref_id,
      pos_user_pkh: #"6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b",
      pos_user_stake_key: Some(
        #"c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3",
      ),
      pos_type: RewardPos,
      pos_amount: amount,
      pos_batcher_fee: 300_000,
      pos_candidate: "cand_1",
    }
  let pos_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let pos_input =
    Input {
      output_reference: pos_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(share_policy_id, pos_datum.pos_candidate, amount)
          |> assets.add(
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
              fee,
            ),
        datum: InlineDatum(pos_datum),
        reference_script: None,
      },
    }
  let user_address =
    when pos_datum.pos_user_stake_key is {
      Some(key) ->
        address.from_verification_key(pos_datum.pos_user_pkh)
          |> address.with_delegation_key(key)
      None -> address.from_verification_key(pos_datum.pos_user_pkh)
    }
  let user_pos_out =
    Output {
      address: user_address,
      value: assets.from_lovelace(2_000_000)
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            50 * decimals,
          ),
      datum: InlineDatum(pos_datum),
      reference_script: None,
    }
  let license_input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"07f157faf99b850b4971034feee28d",
        output_index: 0,
      },
      output: Output {
        address: from_script(#"12"),
        value: assets.add(
          assets.zero,
          license_symbol,
          string.to_bytearray(@"1727715600000"),
          1,
        ),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let license_output =
    Output {
      address: from_script(#"12"),
      value: assets.add(
        assets.zero,
        license_symbol,
        string.to_bytearray(@"1727715600000"),
        1,
      ),
      datum: NoDatum,
      reference_script: None,
    }
  let oracle_datum = OracleDatum { candidate: "cand_1" }
  let oracle_ref =
    OutputReference {
      transaction_id: #"f99b85b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let oracle_input =
    Input {
      output_reference: oracle_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(
              project_info_datum.oracle_policy_id,
              project_info_datum.oracle_token_name,
              1,
            ),
        datum: InlineDatum(oracle_datum),
        reference_script: None,
      },
    }
  let mint =
    assets.from_asset(project_info_datum.share_policy_id, "cand_1", -10)
  let tx =
    Transaction {
      inputs: [pred_input, pos_input, license_input],
      reference_inputs: [project_info_input, oracle_input, psetting_ref_input],
      outputs: [pred_out, user_pos_out, license_output],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let pred_redeemer =
    Reward {
      own_input_idx: 0,
      own_output_idx: 0,
      project_info_idx: 0,
      oracle_ref_input_idx: 1,
      protocol_setting_ref_idx: 2,
      license_idx: 2,
      pos_indices: [(1, 1)],
    }
  project_prediction.spend(
    protocol_nft_policy_id,
    psetting_nft_tn,
    Some(pred_datum),
    pred_redeemer,
    own_ref,
    tx,
  )
}

test predictions__spend_reward__ada() {
  let project_info_script_hash =
    #"8db00d760acf62c0ebaa5ff2c36e9eeb9655d06c0a2f02d9e200aa6f"
  let project_prediction_script_hash =
    #"9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9eeb"
  let protocol_stake_key_hash =
    #"eb9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9e"
  let psetting_datum =
    PSettingDatum {
      pledge: 100_000_000,
      pledge_policy_id: #"",
      pledge_token_name: #"",
      protocol_treasury_script_hash: #"b4971034feee",
      share_ratio: 20000,
      open_fee: 20_000_000,
      open_fee_policy_id: #"",
      open_fee_token_name: #"",
      project_authtoken_policy_id: project_info_nft_policy_id,
      project_info_token_name: project_info_nft_tn,
      project_prediction_token_name: project_prediction_nft_tn,
      protocol_stake_key_hash,
    }
  let psetting_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let psetting_ref_input =
    Input {
      output_reference: psetting_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(protocol_nft_policy_id, psetting_nft_tn, 1),
        datum: InlineDatum(psetting_datum),
        reference_script: None,
      },
    }
  let project_info_ref_id =
    OutputReference {
      transaction_id: #"d07f157faf99b850b4971034feee28",
      output_index: 0,
    }
  let project_info_datum =
    ProjectInfoDatum {
      outref_id: project_info_ref_id,
      owner_pkh: #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      project_name: "test",
      deadline: 123_456,
      payment_policy_id: #"",
      payment_token_name: "",
      batcher_policy_id: #"6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e",
      position_script_hash: #"702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86",
      share_policy_id: #"2d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c425",
      oracle_policy_id: #"f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9",
      oracle_token_name: "oracle_token_name",
      admin_fee_percent: 500,
      // ^ base 10_000
      envelope_amount: 2_000_000,
      candidates: ["cand_1", "cand_2"],
    }
  let project_info_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let project_info_input =
    Input {
      output_reference: project_info_ref,
      output: Output {
        address: from_script(project_info_script_hash)
          |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
        value: assets.zero
          |> assets.add(
              psetting_datum.project_authtoken_policy_id,
              psetting_datum.project_info_token_name,
              1,
            ),
        datum: InlineDatum(project_info_datum),
        reference_script: None,
      },
    }
  let pred_datum =
    ProjectPredictionDatum {
      outref_id: project_info_ref_id,
      total_fee: 0,
      predictions: [("cand_1", 100), ("cand_2", 400)],
    }
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let pred_input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(project_prediction_script_hash)
          |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
        value: assets.from_lovelace(2_000_000)
          |> assets.add(
              psetting_datum.project_authtoken_policy_id,
              psetting_datum.project_prediction_token_name,
              1,
            )
          |> assets.add(
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
              525 * decimals,
            ),
        datum: InlineDatum(pred_datum),
        reference_script: None,
      },
    }
  let amount = 10
  let fee = 10 * project_info_datum.admin_fee_percent * decimals / multiplier
  let pred_out_datum =
    ProjectPredictionDatum {
      outref_id: project_info_ref_id,
      total_fee: pred_datum.total_fee + fee,
      predictions: [("cand_1", 90), ("cand_2", 400)],
    }
  let pred_out =
    Output {
      address: from_script(project_prediction_script_hash)
        |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
      value: assets.from_lovelace(2_000_000)
        |> assets.add(
            psetting_datum.project_authtoken_policy_id,
            psetting_datum.project_prediction_token_name,
            1,
          )
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            475 * decimals,
          )
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            fee,
          ),
      datum: InlineDatum(pred_out_datum),
      reference_script: None,
    }
  let pos_datum =
    PositionDatum {
      outref_id: project_info_ref_id,
      pos_user_pkh: #"6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b",
      pos_user_stake_key: Some(
        #"c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3",
      ),
      pos_type: RewardPos,
      pos_amount: amount,
      pos_batcher_fee: 300_000,
      pos_candidate: "cand_1",
    }
  let pos_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let pos_input =
    Input {
      output_reference: pos_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(share_policy_id, pos_datum.pos_candidate, amount)
          |> assets.add(
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
              fee,
            ),
        datum: InlineDatum(pos_datum),
        reference_script: None,
      },
    }
  let user_address =
    when pos_datum.pos_user_stake_key is {
      Some(key) ->
        address.from_verification_key(pos_datum.pos_user_pkh)
          |> address.with_delegation_key(key)
      None -> address.from_verification_key(pos_datum.pos_user_pkh)
    }
  let user_pos_out =
    Output {
      address: user_address,
      value: assets.from_lovelace(2_000_000)
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            50 * decimals,
          ),
      datum: InlineDatum(pos_datum),
      reference_script: None,
    }
  let license_input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"07f157faf99b850b4971034feee28d",
        output_index: 0,
      },
      output: Output {
        address: from_script(#"12"),
        value: assets.add(
          assets.zero,
          license_symbol,
          string.to_bytearray(@"1727715600000"),
          1,
        ),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let license_output =
    Output {
      address: from_script(#"12"),
      value: assets.add(
        assets.zero,
        license_symbol,
        string.to_bytearray(@"1727715600000"),
        1,
      ),
      datum: NoDatum,
      reference_script: None,
    }
  let oracle_datum = OracleDatum { candidate: "cand_1" }
  let oracle_ref =
    OutputReference {
      transaction_id: #"f99b85b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let oracle_input =
    Input {
      output_reference: oracle_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(
              project_info_datum.oracle_policy_id,
              project_info_datum.oracle_token_name,
              1,
            ),
        datum: InlineDatum(oracle_datum),
        reference_script: None,
      },
    }
  let mint =
    assets.from_asset(project_info_datum.share_policy_id, "cand_1", -10)
  let tx =
    Transaction {
      inputs: [pred_input, pos_input, license_input],
      reference_inputs: [project_info_input, oracle_input, psetting_ref_input],
      outputs: [pred_out, user_pos_out, license_output],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let pred_redeemer =
    Reward {
      own_input_idx: 0,
      own_output_idx: 0,
      project_info_idx: 0,
      oracle_ref_input_idx: 1,
      protocol_setting_ref_idx: 2,
      license_idx: 2,
      pos_indices: [(1, 1)],
    }
  project_prediction.spend(
    protocol_nft_policy_id,
    psetting_nft_tn,
    Some(pred_datum),
    pred_redeemer,
    own_ref,
    tx,
  )
}

test predictions__spend_refund() {
  let project_info_script_hash =
    #"8db00d760acf62c0ebaa5ff2c36e9eeb9655d06c0a2f02d9e200aa6f"
  let project_prediction_script_hash =
    #"9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9eeb"
  let protocol_stake_key_hash =
    #"eb9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9e"
  let psetting_datum =
    PSettingDatum {
      pledge: 100_000_000,
      pledge_policy_id: #"",
      pledge_token_name: #"",
      protocol_treasury_script_hash: #"b4971034feee",
      share_ratio: 20000,
      open_fee: 20_000_000,
      open_fee_policy_id: #"",
      open_fee_token_name: #"",
      project_authtoken_policy_id: project_info_nft_policy_id,
      project_info_token_name: project_info_nft_tn,
      project_prediction_token_name: project_prediction_nft_tn,
      protocol_stake_key_hash,
    }
  let psetting_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let psetting_ref_input =
    Input {
      output_reference: psetting_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(protocol_nft_policy_id, psetting_nft_tn, 1),
        datum: InlineDatum(psetting_datum),
        reference_script: None,
      },
    }
  let project_info_ref_id =
    OutputReference {
      transaction_id: #"d07f157faf99b850b4971034feee28",
      output_index: 0,
    }
  let project_info_datum =
    ProjectInfoDatum {
      outref_id: project_info_ref_id,
      owner_pkh: #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      project_name: "test",
      deadline: 123_456,
      payment_policy_id: #"3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe",
      payment_token_name: "token_name",
      batcher_policy_id: #"6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e",
      position_script_hash: #"702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86",
      share_policy_id: #"2d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c425",
      oracle_policy_id: #"f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9",
      oracle_token_name: "oracle_token_name",
      admin_fee_percent: 500,
      // ^ base 10_000
      envelope_amount: 2_000_000,
      candidates: ["cand_1", "cand_2"],
    }
  let project_info_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let project_info_input =
    Input {
      output_reference: project_info_ref,
      output: Output {
        address: from_script(project_info_script_hash)
          |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
        value: assets.zero
          |> assets.add(
              psetting_datum.project_authtoken_policy_id,
              psetting_datum.project_info_token_name,
              1,
            ),
        datum: InlineDatum(project_info_datum),
        reference_script: None,
      },
    }
  let pred_datum =
    ProjectPredictionDatum {
      outref_id: project_info_ref_id,
      total_fee: 0,
      predictions: [("cand_1", 100), ("cand_2", 400)],
    }
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let pred_input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(project_prediction_script_hash)
          |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
        value: assets.from_lovelace(2_000_000)
          |> assets.add(
              psetting_datum.project_authtoken_policy_id,
              psetting_datum.project_prediction_token_name,
              1,
            )
          |> assets.add(
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
              525 * decimals,
            ),
        datum: InlineDatum(pred_datum),
        reference_script: None,
      },
    }
  let amount = 10
  let fee = 10 * project_info_datum.admin_fee_percent * decimals / multiplier
  let pred_out_datum =
    ProjectPredictionDatum {
      outref_id: project_info_ref_id,
      total_fee: pred_datum.total_fee + fee,
      predictions: [("cand_1", 90), ("cand_2", 400)],
    }
  let pred_out =
    Output {
      address: from_script(project_prediction_script_hash)
        |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
      value: assets.from_lovelace(2_000_000)
        |> assets.add(
            psetting_datum.project_authtoken_policy_id,
            psetting_datum.project_prediction_token_name,
            1,
          )
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            515 * decimals,
          )
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            fee,
          ),
      datum: InlineDatum(pred_out_datum),
      reference_script: None,
    }
  let pos_datum =
    PositionDatum {
      outref_id: project_info_ref_id,
      pos_user_pkh: #"6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b",
      pos_user_stake_key: Some(
        #"c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3",
      ),
      pos_type: RefundPos,
      pos_amount: amount,
      pos_batcher_fee: 300_000,
      pos_candidate: "cand_1",
    }
  let pos_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let pos_input =
    Input {
      output_reference: pos_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(share_policy_id, pos_datum.pos_candidate, amount)
          |> assets.add(
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
              fee,
            ),
        datum: InlineDatum(pos_datum),
        reference_script: None,
      },
    }
  let user_address =
    when pos_datum.pos_user_stake_key is {
      Some(key) ->
        address.from_verification_key(pos_datum.pos_user_pkh)
          |> address.with_delegation_key(key)
      None -> address.from_verification_key(pos_datum.pos_user_pkh)
    }
  let user_pos_out =
    Output {
      address: user_address,
      value: assets.from_lovelace(2_000_000)
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            amount * decimals,
          ),
      datum: InlineDatum(pos_datum),
      reference_script: None,
    }
  let license_input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"07f157faf99b850b4971034feee28d",
        output_index: 0,
      },
      output: Output {
        address: from_script(#"12"),
        value: assets.add(
          assets.zero,
          license_symbol,
          string.to_bytearray(@"1727715600000"),
          1,
        ),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let license_output =
    Output {
      address: from_script(#"12"),
      value: assets.add(
        assets.zero,
        license_symbol,
        string.to_bytearray(@"1727715600000"),
        1,
      ),
      datum: NoDatum,
      reference_script: None,
    }
  let mint =
    assets.from_asset(project_info_datum.share_policy_id, "cand_1", -10)
  let tx =
    Transaction {
      inputs: [pred_input, pos_input, license_input],
      reference_inputs: [project_info_input, psetting_ref_input],
      outputs: [pred_out, user_pos_out, license_output],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let pred_redeemer =
    Refund {
      own_input_idx: 0,
      own_output_idx: 0,
      project_info_idx: 0,
      protocol_setting_ref_idx: 1,
      license_idx: 2,
      pos_indices: [(1, 1)],
    }
  project_prediction.spend(
    protocol_nft_policy_id,
    psetting_nft_tn,
    Some(pred_datum),
    pred_redeemer,
    own_ref,
    tx,
  )
}

test predictions__spend_refund__ada() {
  let project_prediction_script_hash =
    #"9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9eeb"
  let protocol_stake_key_hash =
    #"eb9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9e"
  let psetting_datum =
    PSettingDatum {
      pledge: 100_000_000,
      pledge_policy_id: #"",
      pledge_token_name: #"",
      protocol_treasury_script_hash: #"b4971034feee",
      share_ratio: 20000,
      open_fee: 20_000_000,
      open_fee_policy_id: #"",
      open_fee_token_name: #"",
      project_authtoken_policy_id: project_info_nft_policy_id,
      project_info_token_name: project_info_nft_tn,
      project_prediction_token_name: project_prediction_nft_tn,
      protocol_stake_key_hash,
    }
  let psetting_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let psetting_ref_input =
    Input {
      output_reference: psetting_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(protocol_nft_policy_id, psetting_nft_tn, 1),
        datum: InlineDatum(psetting_datum),
        reference_script: None,
      },
    }
  let project_info_ref_id =
    OutputReference {
      transaction_id: #"d07f157faf99b850b4971034feee28",
      output_index: 0,
    }
  let project_info_datum =
    ProjectInfoDatum {
      outref_id: project_info_ref_id,
      owner_pkh: #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      project_name: "test",
      deadline: 123_456,
      payment_policy_id: #"",
      payment_token_name: "",
      batcher_policy_id: #"6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e",
      position_script_hash: #"702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86",
      share_policy_id: #"2d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c425",
      oracle_policy_id: #"f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9",
      oracle_token_name: "oracle_token_name",
      admin_fee_percent: 500,
      // ^ base 10_000
      envelope_amount: 2_000_000,
      candidates: ["cand_1", "cand_2"],
    }
  let project_info_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let project_info_input =
    Input {
      output_reference: project_info_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(project_info_nft_policy_id, project_info_nft_tn, 1),
        datum: InlineDatum(project_info_datum),
        reference_script: None,
      },
    }
  let pred_datum =
    ProjectPredictionDatum {
      outref_id: project_info_ref_id,
      total_fee: 0,
      predictions: [("cand_1", 100), ("cand_2", 400)],
    }
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let pred_input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(project_prediction_script_hash)
          |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
        value: assets.from_lovelace(2_000_000)
          |> assets.add(
              psetting_datum.project_authtoken_policy_id,
              psetting_datum.project_prediction_token_name,
              1,
            )
          |> assets.add(
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
              525 * decimals,
            ),
        datum: InlineDatum(pred_datum),
        reference_script: None,
      },
    }
  let amount = 10
  let fee = 10 * project_info_datum.admin_fee_percent * decimals / multiplier
  let pred_out_datum =
    ProjectPredictionDatum {
      outref_id: project_info_ref_id,
      total_fee: pred_datum.total_fee + fee,
      predictions: [("cand_1", 90), ("cand_2", 400)],
    }
  let pred_out =
    Output {
      address: from_script(project_prediction_script_hash)
        |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
      value: assets.from_lovelace(2_000_000)
        |> assets.add(
            psetting_datum.project_authtoken_policy_id,
            psetting_datum.project_prediction_token_name,
            1,
          )
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            515 * decimals,
          )
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            fee,
          ),
      datum: InlineDatum(pred_out_datum),
      reference_script: None,
    }
  let pos_datum =
    PositionDatum {
      outref_id: project_info_ref_id,
      pos_user_pkh: #"6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b",
      pos_user_stake_key: Some(
        #"c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe3",
      ),
      pos_type: RefundPos,
      pos_amount: amount,
      pos_batcher_fee: 300_000,
      pos_candidate: "cand_1",
    }
  let pos_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let pos_input =
    Input {
      output_reference: pos_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(share_policy_id, pos_datum.pos_candidate, amount)
          |> assets.add(
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
              fee,
            ),
        datum: InlineDatum(pos_datum),
        reference_script: None,
      },
    }
  let user_address =
    when pos_datum.pos_user_stake_key is {
      Some(key) ->
        address.from_verification_key(pos_datum.pos_user_pkh)
          |> address.with_delegation_key(key)
      None -> address.from_verification_key(pos_datum.pos_user_pkh)
    }
  let user_pos_out =
    Output {
      address: user_address,
      value: assets.from_lovelace(2_000_000)
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            amount * decimals,
          ),
      datum: InlineDatum(pos_datum),
      reference_script: None,
    }
  let license_input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"07f157faf99b850b4971034feee28d",
        output_index: 0,
      },
      output: Output {
        address: from_script(#"12"),
        value: assets.add(
          assets.zero,
          license_symbol,
          string.to_bytearray(@"1727715600000"),
          1,
        ),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let license_output =
    Output {
      address: from_script(#"12"),
      value: assets.add(
        assets.zero,
        license_symbol,
        string.to_bytearray(@"1727715600000"),
        1,
      ),
      datum: NoDatum,
      reference_script: None,
    }
  let mint =
    assets.from_asset(project_info_datum.share_policy_id, "cand_1", -10)
  let tx =
    Transaction {
      inputs: [pred_input, pos_input, license_input],
      reference_inputs: [project_info_input, psetting_ref_input],
      outputs: [pred_out, user_pos_out, license_output],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let pred_redeemer =
    Refund {
      own_input_idx: 0,
      own_output_idx: 0,
      project_info_idx: 0,
      protocol_setting_ref_idx: 1,
      license_idx: 2,
      pos_indices: [(1, 1)],
    }
  project_prediction.spend(
    protocol_nft_policy_id,
    psetting_nft_tn,
    Some(pred_datum),
    pred_redeemer,
    own_ref,
    tx,
  )
}

test predictions__spend_withdraw_admin_fee() {
  let project_info_script_hash =
    #"8db00d760acf62c0ebaa5ff2c36e9eeb9655d06c0a2f02d9e200aa6f"
  let project_prediction_script_hash =
    #"9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9eeb"
  let protocol_stake_key_hash =
    #"eb9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9e"
  let psetting_datum =
    PSettingDatum {
      pledge: 100_000_000,
      pledge_policy_id: #"",
      pledge_token_name: #"",
      protocol_treasury_script_hash: #"b4971034feee",
      share_ratio: 20000,
      open_fee: 20_000_000,
      open_fee_policy_id: #"",
      open_fee_token_name: #"",
      project_authtoken_policy_id: project_info_nft_policy_id,
      project_info_token_name: project_info_nft_tn,
      project_prediction_token_name: project_prediction_nft_tn,
      protocol_stake_key_hash,
    }
  let psetting_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let psetting_ref_input =
    Input {
      output_reference: psetting_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(protocol_nft_policy_id, psetting_nft_tn, 1),
        datum: InlineDatum(psetting_datum),
        reference_script: None,
      },
    }
  let project_info_ref_id =
    OutputReference {
      transaction_id: #"d07f157faf99b850b4971034feee28",
      output_index: 0,
    }
  let project_info_datum =
    ProjectInfoDatum {
      outref_id: project_info_ref_id,
      owner_pkh: #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      project_name: "test",
      deadline: 123_456,
      payment_policy_id: #"3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe",
      payment_token_name: "token_name",
      batcher_policy_id: #"6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e",
      position_script_hash: #"702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86",
      share_policy_id: #"2d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c425",
      oracle_policy_id: #"f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9",
      oracle_token_name: "oracle_token_name",
      admin_fee_percent: 500,
      // ^ base 10_000
      envelope_amount: 2_000_000,
      candidates: ["cand_1", "cand_2"],
    }
  let project_info_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let project_info_input =
    Input {
      output_reference: project_info_ref,
      output: Output {
        address: from_script(project_info_script_hash)
          |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
        value: assets.zero
          |> assets.add(
              psetting_datum.project_authtoken_policy_id,
              psetting_datum.project_info_token_name,
              1,
            ),
        datum: InlineDatum(project_info_datum),
        reference_script: None,
      },
    }
  let pred_datum =
    ProjectPredictionDatum {
      outref_id: project_info_ref_id,
      total_fee: 25 * decimals,
      predictions: [("cand_1", 100), ("cand_2", 400)],
    }
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let pred_input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(project_prediction_script_hash)
          |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
        value: assets.from_lovelace(2_000_000)
          |> assets.add(
              psetting_datum.project_authtoken_policy_id,
              psetting_datum.project_prediction_token_name,
              1,
            )
          |> assets.add(
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
              525 * decimals,
            ),
        datum: InlineDatum(pred_datum),
        reference_script: None,
      },
    }
  let pred_out_datum =
    ProjectPredictionDatum {
      outref_id: project_info_ref_id,
      total_fee: 0,
      predictions: [("cand_1", 100), ("cand_2", 400)],
    }
  let pred_out =
    Output {
      address: from_script(project_prediction_script_hash)
        |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
      value: assets.from_lovelace(2_000_000)
        |> assets.add(
            psetting_datum.project_authtoken_policy_id,
            psetting_datum.project_prediction_token_name,
            1,
          )
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            500 * decimals,
          ),
      datum: InlineDatum(pred_out_datum),
      reference_script: None,
    }
  let treasury_out =
    Output {
      address: from_script(psetting_datum.protocol_treasury_script_hash),
      value: assets.from_lovelace(2_000_000)
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            pred_datum.total_fee * decimals,
          ),
      datum: NoDatum,
      reference_script: None,
    }
  let license_input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"07f157faf99b850b4971034feee28d",
        output_index: 0,
      },
      output: Output {
        address: from_script(#"12"),
        value: assets.add(
          assets.zero,
          license_symbol,
          string.to_bytearray(@"1727715600000"),
          1,
        ),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let license_output =
    Output {
      address: from_script(#"12"),
      value: assets.add(
        assets.zero,
        license_symbol,
        string.to_bytearray(@"1727715600000"),
        1,
      ),
      datum: NoDatum,
      reference_script: None,
    }
  let tx =
    Transaction {
      inputs: [pred_input, license_input],
      reference_inputs: [project_info_input, psetting_ref_input],
      outputs: [pred_out, treasury_out, license_output],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let pred_redeemer =
    WithdrawFee {
      own_input_idx: 0,
      own_output_idx: 0,
      project_info_idx: 0,
      protocol_setting_ref_idx: 1,
      license_idx: 1,
      treasury_out_idx: 1,
    }
  project_prediction.spend(
    protocol_nft_policy_id,
    psetting_nft_tn,
    Some(pred_datum),
    pred_redeemer,
    own_ref,
    tx,
  )
}

test predictions__spend_withdraw_admin_fee__ada() {
  let project_info_script_hash =
    #"8db00d760acf62c0ebaa5ff2c36e9eeb9655d06c0a2f02d9e200aa6f"
  let project_prediction_script_hash =
    #"9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9eeb"
  let protocol_stake_key_hash =
    #"eb9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9e"
  let psetting_datum =
    PSettingDatum {
      pledge: 100_000_000,
      pledge_policy_id: #"",
      pledge_token_name: #"",
      protocol_treasury_script_hash: #"b4971034feee",
      share_ratio: 20000,
      open_fee: 20_000_000,
      open_fee_policy_id: #"",
      open_fee_token_name: #"",
      project_authtoken_policy_id: project_info_nft_policy_id,
      project_info_token_name: project_info_nft_tn,
      project_prediction_token_name: project_prediction_nft_tn,
      protocol_stake_key_hash,
    }
  let psetting_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let psetting_ref_input =
    Input {
      output_reference: psetting_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(protocol_nft_policy_id, psetting_nft_tn, 1),
        datum: InlineDatum(psetting_datum),
        reference_script: None,
      },
    }
  let project_info_ref_id =
    OutputReference {
      transaction_id: #"d07f157faf99b850b4971034feee28",
      output_index: 0,
    }
  let project_info_datum =
    ProjectInfoDatum {
      outref_id: project_info_ref_id,
      owner_pkh: #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      project_name: "test",
      deadline: 123_456,
      payment_policy_id: #"",
      payment_token_name: "",
      batcher_policy_id: #"6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e",
      position_script_hash: #"702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86",
      share_policy_id: #"2d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c425",
      oracle_policy_id: #"f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9",
      oracle_token_name: "oracle_token_name",
      admin_fee_percent: 500,
      // ^ base 10_000
      envelope_amount: 2_000_000,
      candidates: ["cand_1", "cand_2"],
    }
  let project_info_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let project_info_input =
    Input {
      output_reference: project_info_ref,
      output: Output {
        address: from_script(project_info_script_hash)
          |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
        value: assets.zero
          |> assets.add(
              psetting_datum.project_authtoken_policy_id,
              psetting_datum.project_info_token_name,
              1,
            ),
        datum: InlineDatum(project_info_datum),
        reference_script: None,
      },
    }
  let pred_datum =
    ProjectPredictionDatum {
      outref_id: project_info_ref_id,
      total_fee: 25 * decimals,
      predictions: [("cand_1", 100), ("cand_2", 400)],
    }
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let pred_input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_script(project_prediction_script_hash)
          |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
        value: assets.from_lovelace(2_000_000)
          |> assets.add(
              psetting_datum.project_authtoken_policy_id,
              psetting_datum.project_prediction_token_name,
              1,
            )
          |> assets.add(
              project_info_datum.payment_policy_id,
              project_info_datum.payment_token_name,
              525 * decimals,
            ),
        datum: InlineDatum(pred_datum),
        reference_script: None,
      },
    }
  let pred_out_datum =
    ProjectPredictionDatum {
      outref_id: project_info_ref_id,
      total_fee: 0,
      predictions: [("cand_1", 100), ("cand_2", 400)],
    }
  let pred_out =
    Output {
      address: from_script(project_prediction_script_hash)
        |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
      value: assets.from_lovelace(2_000_000)
        |> assets.add(
            psetting_datum.project_authtoken_policy_id,
            psetting_datum.project_prediction_token_name,
            1,
          )
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            500 * decimals,
          ),
      datum: InlineDatum(pred_out_datum),
      reference_script: None,
    }
  let treasury_out =
    Output {
      address: from_script(psetting_datum.protocol_treasury_script_hash),
      value: assets.from_lovelace(2_000_000)
        |> assets.add(
            project_info_datum.payment_policy_id,
            project_info_datum.payment_token_name,
            pred_datum.total_fee * decimals,
          ),
      datum: NoDatum,
      reference_script: None,
    }
  let license_input =
    Input {
      output_reference: OutputReference {
        transaction_id: #"07f157faf99b850b4971034feee28d",
        output_index: 0,
      },
      output: Output {
        address: from_script(#"12"),
        value: assets.add(
          assets.zero,
          license_symbol,
          string.to_bytearray(@"1727715600000"),
          1,
        ),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let license_output =
    Output {
      address: from_script(#"12"),
      value: assets.add(
        assets.zero,
        license_symbol,
        string.to_bytearray(@"1727715600000"),
        1,
      ),
      datum: NoDatum,
      reference_script: None,
    }
  let tx =
    Transaction {
      inputs: [pred_input, license_input],
      reference_inputs: [project_info_input, psetting_ref_input],
      outputs: [pred_out, treasury_out, license_output],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: Interval {
        lower_bound: IntervalBound {
          bound_type: Finite(1727453227635),
          is_inclusive: False,
        },
        upper_bound: IntervalBound {
          bound_type: Finite(1727456400000),
          is_inclusive: False,
        },
      },
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let pred_redeemer =
    WithdrawFee {
      own_input_idx: 0,
      own_output_idx: 0,
      project_info_idx: 0,
      protocol_setting_ref_idx: 1,
      license_idx: 1,
      treasury_out_idx: 1,
    }
  project_prediction.spend(
    protocol_nft_policy_id,
    psetting_nft_tn,
    Some(pred_datum),
    pred_redeemer,
    own_ref,
    tx,
  )
}
