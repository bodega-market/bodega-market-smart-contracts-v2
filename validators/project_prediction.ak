use aiken/collection/dict.{Dict}
use cardano/transaction.{OutputReference, Transaction}

pub type ProjectPredictionRedeemer {
  UpdateVote
  Update
  PayOut
  Refund
}

pub type ProjectPredictionDatum {
  candidate_votes: Dict<ByteArray, Int>,
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
