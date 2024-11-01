use aiken/collection/dict.{Dict}
use cardano/transaction.{OutputReference, Transaction}

pub type ProjectManagerRedeemer {
  UpdateVote
  Update
  PayOut
  Refund
}

pub type ProjectManagerDatum {
  candidate_votes: Dict<ByteArray, Int>,
}

validator project_manager {
  spend(
    _datum: Option<ProjectManagerDatum>,
    _redeemer: ProjectManagerRedeemer,
    _own_ref: OutputReference,
    _self: Transaction,
  ) {
    True
  }

  else(_) {
    fail
  }
}
