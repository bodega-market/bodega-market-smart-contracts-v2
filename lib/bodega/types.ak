use aiken/crypto.{Blake2b_224, Hash, VerificationKey}
use cardano/assets.{AssetName, PolicyId}
use cardano/transaction.{OutputReference}

pub type PubKeyHash =
  Hash<Blake2b_224, VerificationKey>

pub type Asset {
  policy_id: PolicyId,
  asset_name: AssetName,
}

pub type ProjectInfoDatum {
  outref_id: OutputReference,
  owner_pkh: ByteArray,
  project_name: ByteArray,
  deadline: Int,
  payment_policy_id: ByteArray,
  payment_token_name: ByteArray,
  batcher_policy_id: ByteArray,
  position_script_hash: ByteArray,
  share_policy_id: ByteArray,
  oracle_policy_id: ByteArray,
  oracle_token_name: ByteArray,
  admin_fee_percent: Int,
  // ^ base 10_000
  envelope_amount: Int,
  candidates: List<ByteArray>,
}

pub type ProjectPredictionDatum {
  outref_id: OutputReference,
  total_fee: Int,
  predictions: List<(ByteArray, Int)>,
}

pub type PSettingDatum {
  pledge: Int,
  pledge_policy_id: ByteArray,
  pledge_token_name: ByteArray,
  protocol_treasury_script_hash: ByteArray,
  share_ratio: Int,
  // ^ Base: 10000
  open_fee: Int,
  open_fee_policy_id: ByteArray,
  open_fee_token_name: ByteArray,
  project_authtoken_policy_id: ByteArray,
  project_info_token_name: ByteArray,
  project_prediction_token_name: ByteArray,
  protocol_stake_key_hash: ByteArray,
}

pub type PositionType {
  BuyPos
  RewardPos
  RefundPos
}

pub type PositionDatum {
  outref_id: OutputReference,
  pos_user_pkh: PubKeyHash,
  pos_user_stake_key: Option<PubKeyHash>,
  pos_type: PositionType,
  pos_amount: Int,
  pos_batcher_fee: Int,
  pos_candidate: ByteArray,
}

pub type OracleDatum {
  candidate: ByteArray,
}
