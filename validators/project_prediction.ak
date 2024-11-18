use bodega/types.{ProjectPredictionDatum}
use cardano/transaction.{OutputReference, Transaction}

pub type ProjectPredictionRedeemer {
  UpdateVote
  Update
  PayOut
  Refund
}

validator project_prediction {
  spend(
    _datum: Option<ProjectPredictionDatum>,
    _redeemer: ProjectPredictionRedeemer,
    _own_ref: OutputReference,
    _self: Transaction,
  ) {
    True
  }

  else(_) {
    fail
  }
}
