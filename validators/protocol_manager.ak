use aiken/collection/list
use cardano/address.{Credential}
use cardano/transaction.{OutputReference, Transaction}

// pub type PManagerDatum {
//   admin_pkh: ByteArray,
// }

validator protocol_manager(admin_pkh: ByteArray) {
  spend(
    _option_datum: Option<Data>,
    _redeemer: Data,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    let Transaction { extra_signatories, .. } = self
    list.has(extra_signatories, admin_pkh)
  }

  withdraw(_redeemer: Data, _account: Credential, self: Transaction) {
    let Transaction { extra_signatories, .. } = self
    list.has(extra_signatories, admin_pkh)
  }

  else(_) {
    fail
  }
}
