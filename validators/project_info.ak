use aiken/collection/list
use bodega/types.{ProjectInfoDatum}
use cardano/transaction.{InlineDatum, OutputReference, Transaction}

pub type PMSpendRedeemer {
  own_in_idx: Int,
  own_out_idx: Int,
}

validator project_info(_seed: OutputReference) {
  spend(
    datum: Option<ProjectInfoDatum>,
    redeemer: PMSpendRedeemer,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    let Transaction { inputs, outputs, extra_signatories, .. } = self
    expect Some(own_datum) = datum
    expect Some(own_input) = list.at(inputs, redeemer.own_in_idx)
    expect Some(own_output) = list.at(outputs, redeemer.own_out_idx)
    expect
      own_input.output.address == own_output.address && own_input.output.value == own_output.value
    expect InlineDatum(own_out_inline_datum) = own_output.datum
    expect own_output_datum: ProjectInfoDatum = own_out_inline_datum
    expect own_datum.project_name == own_output_datum.project_name
    expect own_datum.deadline == own_output_datum.deadline
    expect own_datum.payment_policy_id == own_output_datum.payment_policy_id
    expect own_datum.payment_token_name == own_output_datum.payment_token_name
    expect own_datum.batcher_policy_id == own_output_datum.batcher_policy_id
    expect
      own_datum.treasury_script_hash == own_output_datum.treasury_script_hash
    expect
      own_datum.position_script_hash == own_output_datum.position_script_hash
    expect own_datum.share_policy_id == own_output_datum.share_policy_id
    expect own_datum.admin_fee_percent == own_output_datum.admin_fee_percent
    expect own_datum.envelope_amount == own_output_datum.envelope_amount
    expect own_datum.candidates == own_output_datum.candidates
    list.has(extra_signatories, own_datum.owner_pkh)
  }

  else(_) {
    fail
  }
}
