use aiken/collection/dict
use aiken/collection/list
use aiken/interval
use aiken/primitive/string
use bodega/constants.{project_info_nft_tn, project_prediction_nft_tn}
use bodega/types.{PSettingDatum, ProjectInfoDatum, ProjectPredictionDatum}
use cardano/address.{Inline, Script, from_script, from_verification_key}
use cardano/address/credential
use cardano/assets.{PolicyId, flatten}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}

pub type PATMintRedeemer {
  seed: OutputReference,
  protocol_setting_ref_idx: Int,
  project_info_out_idx: Int,
  project_prediction_out_idx: Int,
  protocol_treasury_out_idx: Int,
}

pub fn is_project_info_datum_valid(d: ProjectInfoDatum) -> Bool {
  let correct_candidates =
    list.length(list.unique(d.candidates)) == list.length(d.candidates)
  d.deadline > 0 && d.admin_fee_percent > 0 && d.envelope_amount > 0 && correct_candidates
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
            let (candidate, amount) = cand
            acc && candidate == c && amount == 0
          },
        )
  d.total_fee == 0 && check_candidates
}

validator project_authtoken_mp(
  project_info_script_hash: ByteArray,
  project_prediction_script_hash: ByteArray,
  psettings_nft_policy_id: ByteArray,
  psettings_nft_tn: ByteArray,
) {
  mint(redeemer: PATMintRedeemer, policy_id: PolicyId, self: Transaction) {
    let Transaction { mint, outputs, inputs, reference_inputs, .. } = self
    expect Some(ref_protocol_setting_input) =
      list.at(reference_inputs, redeemer.protocol_setting_ref_idx)
    expect
      assets.quantity_of(
        ref_protocol_setting_input.output.value,
        psettings_nft_policy_id,
        psettings_nft_tn,
      ) == 1
    expect InlineDatum(protocol_setting_inline_datum) =
      ref_protocol_setting_input.output.datum
    expect protocol_setting_datum: PSettingDatum = protocol_setting_inline_datum
    expect
      list.any(
        inputs,
        fn(inp) {
          inp.output_reference.transaction_id == redeemer.seed.transaction_id
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
    expect Some(protocol_treasury_output) =
      list.at(outputs, redeemer.protocol_treasury_out_idx)
    let project_info_cred = Script(project_info_script_hash)
    let project_prediction_cred = Script(project_prediction_script_hash)
    let protocol_treasury_cred =
      Script(protocol_setting_datum.protocol_treasury_script_hash)
    let protocol_stake_cred =
      Inline(Script(protocol_setting_datum.protocol_stake_key_hash))
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
    expect
      credential.compare(
        protocol_treasury_cred,
        protocol_treasury_output.address.payment_credential,
      ) == Equal
    expect Some(project_info_stake_cred) =
      project_info_output.address.stake_credential
    expect Some(project_prediction_stake_cred) =
      project_prediction_output.address.stake_credential
    expect Some(protocol_treasury_stake_cred) =
      protocol_treasury_output.address.stake_credential
    expect project_info_stake_cred == protocol_stake_cred
    expect project_prediction_stake_cred == protocol_stake_cred
    expect protocol_treasury_stake_cred == protocol_stake_cred
    expect NoDatum = protocol_treasury_output.datum
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
    expect list.length(flatten(protocol_treasury_output.value)) <= 2
    expect
      assets.quantity_of(
        protocol_treasury_output.value,
        protocol_setting_datum.open_fee_policy_id,
        protocol_setting_datum.open_fee_token_name,
      ) >= protocol_setting_datum.open_fee
    True
  }

  else(_) {
    fail
  }
}

test project_authtoken_mp_success() {
  let own_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850f856d8da3494c70b19b521cfe690258e26",
      output_index: 0,
    }
  let seed_input =
    Input {
      output_reference: own_ref,
      output: Output {
        address: from_verification_key(#""),
        value: assets.from_lovelace(2_000_000),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let own_policy_id =
    #"a5ff2c36e9eeb9655d06c0a2f02d9e200aa6f8db00d760acf62c0eba"
  let project_info_script_hash =
    #"8db00d760acf62c0ebaa5ff2c36e9eeb9655d06c0a2f02d9e200aa6f"
  let project_prediction_script_hash =
    #"9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9eeb"
  let psettings_nft_policy_id =
    #"2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9eeb9655d06c0a"
  let psettings_nft_tn = string.to_bytearray(@"PROTOCOL_SETTINGS_NFT")
  let mint =
    assets.from_asset(own_policy_id, project_info_nft_tn, 1)
      |> assets.add(own_policy_id, project_prediction_nft_tn, 1)
  let psetting_datum =
    PSettingDatum {
      pledge: 100_000_000,
      pledge_policy_id: #"",
      pledge_token_name: #"",
      protocol_treasury_script_hash: #"60acf62c0ebaa5ff2c36e9eeb9655d06c0a2f02d9e200aa6f8db00d7",
      share_ratio: 20000,
      open_fee: 20_000_000,
      open_fee_policy_id: #"",
      open_fee_token_name: #"",
      project_authtoken_policy_id: #"",
      project_info_token_name: #"",
      project_prediction_token_name: #"",
      protocol_stake_key_hash: #"eb9655d06c0a2f02d9e200aa6f8db00d760acf62c0ebaa5ff2c36e9e",
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
          |> assets.add(psettings_nft_policy_id, psettings_nft_tn, 1),
        datum: InlineDatum(psetting_datum),
        reference_script: None,
      },
    }
  let project_info_ref_id =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let project_info_datum =
    ProjectInfoDatum {
      outref_id: project_info_ref_id,
      owner_pkh: #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      owner_stake_key: Some(
        #"c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648",
      ),
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
  let project_info_output =
    Output {
      address: from_script(project_info_script_hash)
        |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
      value: assets.from_lovelace(100_000_000)
        |> assets.add(own_policy_id, project_info_nft_tn, 1),
      datum: InlineDatum(project_info_datum),
      reference_script: None,
    }
  let pred_datum =
    ProjectPredictionDatum {
      outref_id: project_info_ref_id,
      total_fee: 0,
      predictions: [("cand_1", 0), ("cand_2", 0)],
    }
  let pred_output =
    Output {
      address: from_script(project_prediction_script_hash)
        |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
      value: assets.from_lovelace(2_000_000)
        |> assets.add(own_policy_id, project_prediction_nft_tn, 1),
      datum: InlineDatum(pred_datum),
      reference_script: None,
    }
  let protocol_treasury_output =
    Output {
      address: from_script(psetting_datum.protocol_treasury_script_hash)
        |> address.with_delegation_script(psetting_datum.protocol_stake_key_hash),
      value: assets.zero
        |> assets.add(
            psetting_datum.open_fee_policy_id,
            psetting_datum.open_fee_policy_id,
            psetting_datum.open_fee,
          ),
      datum: NoDatum,
      reference_script: None,
    }
  let tx =
    Transaction {
      inputs: [seed_input],
      reference_inputs: [psetting_ref_input],
      outputs: [project_info_output, pred_output, protocol_treasury_output],
      fee: 0,
      mint,
      certificates: [],
      withdrawals: [],
      validity_range: interval.everything,
      extra_signatories: [],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  let redeemer =
    PATMintRedeemer {
      seed: own_ref,
      protocol_setting_ref_idx: 0,
      project_info_out_idx: 0,
      project_prediction_out_idx: 1,
      protocol_treasury_out_idx: 2,
    }
  project_authtoken_mp.mint(
    project_info_script_hash,
    project_prediction_script_hash,
    psettings_nft_policy_id,
    psettings_nft_tn,
    redeemer,
    own_policy_id,
    tx,
  )
}
