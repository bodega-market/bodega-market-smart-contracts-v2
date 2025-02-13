use aiken/collection/dict
use aiken/collection/list
use aiken/interval
use bodega/constants.{project_info_nft_tn}
use bodega/test_constants.{pmanager_nft_asset, project_info_nft_policy_id}
use bodega/types.{Asset, ProjectInfoDatum}
use cardano/address.{from_script}
use cardano/assets
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}

pub type PMSpendRedeemer {
  Update { own_in_idx: Int, own_out_idx: Int }
  Close { protocol_manager_in_idx: Int }
}

validator project_info(protocol_manager_nft: Asset) {
  spend(
    datum: Option<ProjectInfoDatum>,
    redeemer: PMSpendRedeemer,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    let Transaction { inputs, outputs, extra_signatories, .. } = self
    when redeemer is {
      Update { own_in_idx, own_out_idx } -> {
        expect Some(own_datum) = datum
        expect Some(own_input) = list.at(inputs, own_in_idx)
        expect Some(own_output) = list.at(outputs, own_out_idx)
        expect InlineDatum(own_out_inline_datum) = own_output.datum
        expect own_output_datum: ProjectInfoDatum = own_out_inline_datum
        expect and {
            own_input.output.address == own_output.address && own_input.output.value == own_output.value,
            own_datum.project_name == own_output_datum.project_name,
            own_datum.deadline == own_output_datum.deadline,
            own_datum.payment_policy_id == own_output_datum.payment_policy_id,
            own_datum.payment_token_name == own_output_datum.payment_token_name,
            own_datum.batcher_policy_id == own_output_datum.batcher_policy_id,
            own_datum.position_script_hash == own_output_datum.position_script_hash,
            own_datum.share_policy_id == own_output_datum.share_policy_id,
            own_datum.admin_fee_percent == own_output_datum.admin_fee_percent,
            own_datum.envelope_amount == own_output_datum.envelope_amount,
            own_datum.candidates == own_output_datum.candidates,
            own_datum.outref_id == own_output_datum.outref_id,
            list.has(extra_signatories, own_datum.owner_pkh),
          }
        True
      }
      Close { protocol_manager_in_idx } -> {
        expect Some(protocol_manager_input) =
          list.at(inputs, protocol_manager_in_idx)
        expect
          assets.quantity_of(
            protocol_manager_input.output.value,
            protocol_manager_nft.policy_id,
            protocol_manager_nft.asset_name,
          ) == 1
        True
      }
    }
  }

  else(_) {
    fail
  }
}

test project_info__spend_success() {
  let project_info_ref_id =
    OutputReference {
      transaction_id: #"2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c",
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
  let project_info_redeemer = Update { own_in_idx: 0, own_out_idx: 0 }
  let project_info_ref_id =
    OutputReference {
      transaction_id: #"2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c",
      output_index: 0,
    }
  let project_info_out_datum =
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
      oracle_policy_id: #"7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c",
      oracle_token_name: "oracle_token_name",
      admin_fee_percent: 500,
      // ^ base 10_000
      envelope_amount: 2_000_000,
      candidates: ["cand_1", "cand_2"],
    }
  let project_info_output =
    Output {
      address: from_script(#"11"),
      value: assets.zero
        |> assets.add(project_info_nft_policy_id, project_info_nft_tn, 1),
      datum: InlineDatum(project_info_out_datum),
      reference_script: None,
    }
  let tx =
    Transaction {
      inputs: [project_info_input],
      reference_inputs: [],
      outputs: [project_info_output],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: interval.everything,
      extra_signatories: [
        #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      ],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  project_info.spend(
    pmanager_nft_asset,
    Some(project_info_out_datum),
    project_info_redeemer,
    project_info_ref,
    tx,
  )
}

test project_info__spend_fail() fail {
  let project_info_ref_id =
    OutputReference {
      transaction_id: #"2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c",
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
  let project_info_redeemer = Update { own_in_idx: 0, own_out_idx: 0 }
  let project_info_ref_id =
    OutputReference {
      transaction_id: #"2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c",
      output_index: 0,
    }
  let project_info_out_datum =
    ProjectInfoDatum {
      outref_id: project_info_ref_id,
      owner_pkh: #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      owner_stake_key: Some(
        #"c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648",
      ),
      project_name: "test",
      deadline: 123_456,
      payment_policy_id: #"3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c7cffe",
      payment_token_name: "other_token_name",
      batcher_policy_id: #"6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e",
      position_script_hash: #"702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86",
      share_policy_id: #"2d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c425",
      oracle_policy_id: #"7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c2e49e6648c",
      oracle_token_name: "oracle_token_name",
      admin_fee_percent: 500,
      // ^ base 10_000
      envelope_amount: 2_000_000,
      candidates: ["cand_1", "cand_2"],
    }
  let project_info_output =
    Output {
      address: from_script(#"11"),
      value: assets.zero
        |> assets.add(project_info_nft_policy_id, project_info_nft_tn, 1),
      datum: InlineDatum(project_info_out_datum),
      reference_script: None,
    }
  let tx =
    Transaction {
      inputs: [project_info_input],
      reference_inputs: [],
      outputs: [project_info_output],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: interval.everything,
      extra_signatories: [
        #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      ],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  project_info.spend(
    pmanager_nft_asset,
    Some(project_info_datum),
    project_info_redeemer,
    project_info_ref,
    tx,
  )
}

test project_info__spend__close() {
  let project_info_ref_id =
    OutputReference {
      transaction_id: #"2e49e6648c7cffe3c8f2b6b7d779788f50f4c9f9c4252d86702c2f4c",
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
  let project_manager_ref =
    OutputReference {
      transaction_id: #"b4971034feee28d07f157faf99b850",
      output_index: 0,
    }
  let project_manager_input =
    Input {
      output_reference: project_manager_ref,
      output: Output {
        address: from_script(#"11"),
        value: assets.zero
          |> assets.add(
              pmanager_nft_asset.policy_id,
              pmanager_nft_asset.asset_name,
              1,
            ),
        datum: NoDatum,
        reference_script: None,
      },
    }
  let project_info_redeemer = Close { protocol_manager_in_idx: 0 }
  let tx =
    Transaction {
      inputs: [project_manager_input, project_info_input],
      reference_inputs: [],
      outputs: [],
      fee: 0,
      mint: assets.zero,
      certificates: [],
      withdrawals: [],
      validity_range: interval.everything,
      extra_signatories: [
        #"f4c9f9c4252d86702c2f4c2e49e6648c7cffe3c8f2b6b7d779788f50",
      ],
      redeemers: [],
      datums: dict.empty,
      id: #"0000000000000000000000000000000000000000000000000000000000000000",
      votes: [],
      proposal_procedures: [],
      current_treasury_amount: None,
      treasury_donation: None,
    }
  project_info.spend(
    pmanager_nft_asset,
    Some(project_info_datum),
    project_info_redeemer,
    project_info_ref,
    tx,
  )
}
