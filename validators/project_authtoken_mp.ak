use aiken/collection/list
use bodega/constants.{project_info_nft_tn, project_prediction_nft_tn}
use bodega/types.{PSettingDatum, ProjectInfoDatum, ProjectPredictionDatum}
use cardano/address.{Inline, Script}
use cardano/address/credential
use cardano/assets.{PolicyId, flatten}
use cardano/transaction.{InlineDatum, OutputReference, Transaction}

pub type PATMintRedeemer {
  protocol_setting_ref_idx: Int,
  project_info_out_idx: Int,
  project_prediction_out_idx: Int,
}

pub fn is_project_info_datum_valid(d: ProjectInfoDatum) -> Bool {
  d.deadline > 0 && d.admin_fee_percent > 0 && d.envelope_amount > 0
}

pub fn is_project_prediction_datum_valid(
  d: ProjectPredictionDatum,
  candidates: List<ByteArray>,
) -> Bool {
  let check_candidates =
    d.predictions
      |> list.indexed_foldr(
          True,
          fn(idx, cand, acc) {
            expect Some(c) = list.at(candidates, idx)
            let Pair(candidate, amount) = cand
            acc && candidate == c && amount == False
          },
        )
  d.total_fee == 0 && check_candidates
}

validator project_authtoken_mp(
  seed: OutputReference,
  project_info_script_hash: ByteArray,
  project_prediction_script_hash: ByteArray,
  protocol_stake_key_hash: ByteArray,
  psettings_nft_policy_id: ByteArray,
  psettings_nft_policy_tn: ByteArray,
) {
  mint(redeemer: PATMintRedeemer, policy_id: PolicyId, self: Transaction) {
    let Transaction { mint, outputs, inputs, reference_inputs, .. } = self
    expect Some(ref_protocol_setting_input) =
      list.at(reference_inputs, redeemer.protocol_setting_ref_idx)
    expect
      assets.quantity_of(
        ref_protocol_setting_input.output.value,
        psettings_nft_policy_id,
        psettings_nft_policy_tn,
      ) == 1
    expect InlineDatum(protocol_setting_inline_datum) =
      ref_protocol_setting_input.output.datum
    expect protocol_setting_datum: PSettingDatum = protocol_setting_inline_datum
    expect
      list.any(
        inputs,
        fn(inp) {
          trace seed
          trace inp.output_reference
          inp.output_reference.transaction_id == seed.transaction_id
        },
      )
    let project_info_nft = assets.from_asset(policy_id, project_info_nft_tn, 1)
    let project_prediction_nft =
      assets.from_asset(policy_id, project_prediction_nft_tn, 1)
    let merged_mint = assets.merge(project_info_nft, project_prediction_nft)
    expect Some(project_info_output) =
      list.at(outputs, redeemer.project_info_out_idx)
    expect Some(project_prediction_output) =
      list.at(outputs, redeemer.project_prediction_out_idx)
    let project_info_cred = Script(project_info_script_hash)
    let project_prediction_cred = Script(project_prediction_script_hash)
    let protocol_stake_cred = Inline(Script(protocol_stake_key_hash))
    expect
      credential.compare(
        project_info_cred,
        project_info_output.address.payment_credential,
      ) == Equal
    expect
      credential.compare(
        project_prediction_cred,
        project_prediction_output.address.payment_credential,
      ) == Equal
    expect Some(project_info_stake_cred) =
      project_info_output.address.stake_credential
    expect Some(project_prediction_stake_cred) =
      project_prediction_output.address.stake_credential
    expect project_info_stake_cred == protocol_stake_cred
    expect project_prediction_stake_cred == protocol_stake_cred
    expect InlineDatum(project_info_inline_datum) = project_info_output.datum
    expect project_info_datum: ProjectInfoDatum = project_info_inline_datum
    expect is_project_info_datum_valid(project_info_datum)
    expect
      assets.quantity_of(
        project_info_output.value,
        policy_id,
        project_info_nft_tn,
      ) == 1
    expect
      assets.quantity_of(
        project_info_output.value,
        protocol_setting_datum.pledge_policy_id,
        protocol_setting_datum.pledge_token_name,
      ) >= protocol_setting_datum.pledge
    expect InlineDatum(project_prediction_inline_datum) =
      project_prediction_output.datum
    expect project_prediction_datum: ProjectPredictionDatum =
      project_prediction_inline_datum
    expect
      is_project_prediction_datum_valid(
        project_prediction_datum,
        project_info_datum.candidates,
      )
    expect
      assets.quantity_of(
        project_prediction_output.value,
        policy_id,
        project_prediction_nft_tn,
      ) == 1
    expect merged_mint == mint
    expect list.length(flatten(project_info_output.value)) <= 3
    expect list.length(flatten(project_prediction_output.value)) == 2
    True
  }

  else(_) {
    fail
  }
}
