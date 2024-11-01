use bodega/types.{ProjectInfoDatum}
use cardano/transaction.{OutputReference, Transaction}

pub type PMSpendRedeemer {
  Update
}

validator project_info(_seed: OutputReference) {
  spend(
    _datum: Option<ProjectInfoDatum>,
    _redeemer: PMSpendRedeemer,
    _own_ref: OutputReference,
    _self: Transaction,
  ) {
    True
  }

  else(_) {
    fail
  }
}
