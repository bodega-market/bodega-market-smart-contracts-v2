use aiken/collection/list
use bodega/types.{Asset}
use cardano/assets
use cardano/transaction.{OutputReference, Transaction}

pub type RefScriptRedeemer {
  protocol_manager_idx: Int,
}

validator ref_script_lock(protocol_manager_nft: Asset) {
  spend(
    _option_datum: Option<Data>,
    redeemer: RefScriptRedeemer,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    let Transaction { inputs, .. } = self
    expect Some(protocol_manager_input) =
      list.at(inputs, redeemer.protocol_manager_idx)
    assets.quantity_of(
      protocol_manager_input.output.value,
      protocol_manager_nft.policy_id,
      protocol_manager_nft.asset_name,
    ) == 1
  }

  mint(redeemer: RefScriptRedeemer, _policy_id: ByteArray, self: Transaction) {
    let Transaction { outputs, .. } = self
    expect Some(protocol_manager_output) =
      list.at(outputs, redeemer.protocol_manager_idx)
    assets.quantity_of(
      protocol_manager_output.value,
      protocol_manager_nft.policy_id,
      protocol_manager_nft.asset_name,
    ) == 1
  }

  else(_) {
    fail
  }
}
