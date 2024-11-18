use aiken/crypto.{Blake2b_224, Hash, VerificationKey}
use cardano/assets.{AssetName, PolicyId}

pub type PubKeyHash =
  Hash<Blake2b_224, VerificationKey>

pub type Asset {
  policy_id: PolicyId,
  asset_name: AssetName,
}

pub type ProjectInfoDatum {
  owner_pkh: ByteArray,
  project_name: ByteArray,
  deadline: Int,
  payment_policy_id: ByteArray,
  payment_token_name: ByteArray,
  batcher_policy_id: ByteArray,
  treasury_script_hash: ByteArray,
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
  total_fee: Int,
  predictions: List<Pair<ByteArray, Int>>,
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
}

pub type PositionType {
  BuyPos
  RewardPos
}

pub type PositionDatum {
  pos_user_pkh: PubKeyHash,
  pos_user_stake_key: PubKeyHash,
  pos_type: PositionType,
  pos_amount: Int,
  pos_batcher_fee: Int,
  pos_candidate: ByteArray,
}

pub type ProjectPredictionParams {
  project_prediction_nft: Asset,
  project_info_nft: Asset,
}
