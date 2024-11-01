use aiken/crypto.{Blake2b_224, Hash, VerificationKey}
use cardano/assets.{AssetName, PolicyId}

pub type PubKeyHash =
  Hash<Blake2b_224, VerificationKey>

pub type Asset {
  policy_id: PolicyId,
  asset_name: AssetName,
}

pub type ProjectInfoDatum {
  project_name: ByteArray,
  deadline: Int,
  payment_policy_id: ByteArray,
  payment_token_name: ByteArray,
  batcher_policy_id: ByteArray,
  treasury_script_hash: ByteArray,
  position_script_hash: ByteArray,
  oracle_policy_id: ByteArray,
  oracle_token_name: ByteArray,
  admin_fee: Int,
  envelope_amount: Int,
  candidates: List<ByteArray>,
}

pub type PSettingDatum {
  pledge: Int,
  pledge_policy_id: ByteArray,
  pledge_token_name: ByteArray,
  protocol_treasury_script_hash: ByteArray,
  share_ratio: Int,
  // Base: 10000
  open_fee: Int,
  open_fee_policy_id: ByteArray,
  open_fee_token_name: ByteArray,
}
