// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SUT is ERC721PresetMinterPauserAutoId {
    using SafeMath for uint256;

    string private _baseTokenURI = "https://dapp.sfos.io/testapi/dapp/wallet/NFT?type=0&tokenId=";

    constructor() ERC721PresetMinterPauserAutoId("StarFish-User-NFT", "SUT", _baseTokenURI) {}

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseTokenURI(string memory str) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "setBaseTokenURI: must have ADMIN role to edit.");
        _baseTokenURI = str;
    }
}
