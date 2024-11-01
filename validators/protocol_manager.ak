use aiken/collection/list
use cardano/transaction.{OutputReference, Transaction}

pub type PManagerDatum {
  admin_pkh: ByteArray,
}

validator protocol_manager {
  spend(
    option_datum: Option<PManagerDatum>,
    _redeemer: Data,
    _own_ref: OutputReference,
    self: Transaction,
  ) {
    expect Some(datum) = option_datum
    let own_input_datum: PManagerDatum = datum
    let Transaction { extra_signatories, .. } = self
    list.has(extra_signatories, own_input_datum.admin_pkh)
  }

  else(_) {
    fail
  }
}
