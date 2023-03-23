# Marketplace Contract

Features:
- Can be deployed as an upgradeable proxy contract.
- Works for buying/selling both ERC721s & ERC1155s.
- Uses signature based bids, signature and necessary detals to rebuild the signature requires as arguments in functions `purchaseWithEth` and `acceptBid`
- Uses chainId & address(this) in the signature to make sure signatures cannot be replayed across other instances of this contract or across different chains.
- Uses the address of the bid/listing creator to ensure tokens can only be bought from/sold to the person who created the Item listing/bid.
- Uses an expiry on bids/listings.
- ERC20 token used by the bid is in the signature & reverts if that token is not on the list of whitelisted ERC20s.