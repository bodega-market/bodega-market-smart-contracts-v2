use bodega/constants.{
  pmanager_nft_tn, project_info_nft_tn, project_prediction_nft_tn,
}
use bodega/types.{Asset}

pub const protocol_nft_policy_id =
  #"b5bab2940b09a2350d7814b3077822f622e740e3921812d6c58112bb"

pub const project_info_nft_policy_id =
  #"2e740e3921812d6c58112bbb5bab2940b09a2350d7814b3077822f62"

pub const project_prediction_nft_policy_id =
  #"0b09a2350d7814b3077822f622e740e3921812d6c58112bbb5bab294"

pub const share_policy_id =
  #"622e740e3921812d6c58112bbb5bab2940b09a2350d7814b3077822f"

pub const pos_user_pkh =
  #"d48838fee1e840857dab28a04dd88193aec8c297b85d8150c0a1f5cc"

pub const pos_user_stake_key =
  #"d88193aec8c297b85d8150c0a1f5ccd48838fee1e840857dab28a04d"

pub const pmanager_nft_asset =
  Asset { policy_id: protocol_nft_policy_id, asset_name: pmanager_nft_tn }

pub const project_info_nft_asset =
  Asset {
    policy_id: project_info_nft_policy_id,
    asset_name: project_info_nft_tn,
  }

pub const project_prediction_nft_asset =
  Asset {
    policy_id: project_prediction_nft_policy_id,
    asset_name: project_prediction_nft_tn,
  }
