use aiken/collection/list
use bodega/types.{Asset}
use cardano/assets.{flatten}
use cardano/transaction.{Transaction}

pub type LicenseRedeemer {
  dead_line: ByteArray,
  protocol_manager_in_idx: Int,
}

validator batcher_mp(protocol_manager_nft: Asset, _project_name: ByteArray) {
  mint(redeemer: LicenseRedeemer, policy_id: ByteArray, self: Transaction) {
    let Transaction { inputs, mint, .. } = self
    expect Some(protocol_manager_input) =
      list.at(inputs, redeemer.protocol_manager_in_idx)
    expect
      assets.quantity_of(
        protocol_manager_input.output.value,
        protocol_manager_nft.policy_id,
        protocol_manager_nft.asset_name,
      ) == 1
    flatten(mint) == [(policy_id, redeemer.dead_line, 1)]
  }

  else(_) {
    fail
  }
}
