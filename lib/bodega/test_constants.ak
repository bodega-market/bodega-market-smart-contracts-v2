use aiken/primitive/string
use bodega/types.{Asset}

pub const protocol_nft_policy_id =
  #"b5bab2940b09a2350d7814b3077822f622e740e3921812d6c58112bb"

pub const psetting_nft_tn = string.to_bytearray(@"PROTOCOL_SETTINGS_NFT")

pub const pmanager_nft_tn = string.to_bytearray(@"PROTOCOL_MANAGER_NFT")

pub const pmanager_nft_asset =
  Asset { policy_id: protocol_nft_policy_id, asset_name: pmanager_nft_tn }
