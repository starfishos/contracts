// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract KOL_ProtectV2 is Ownable, ERC721Holder {
    using SafeERC20 for IERC20;

    address public kol = 0x127fBE36D375Fe178f60C37DAeD5AeE7843cD311;
    address public usdt = 0x55d398326f99059fF775485246999027B3197955;

    bool public protect;

    function app(uint256 tokenId) external {
        require(protect, "protect uneffect");
        IERC721(kol).safeTransferFrom(msg.sender, address(this), tokenId);
        uint256 basic = 0;
        if (tokenId <= 899) {
            basic = 1000e18;
        } else if (tokenId <= 1399) {
            basic = 1100e18;
        } else if (tokenId <= 1999) {
            basic = 1200e18;
        }
        IERC20(usdt).safeTransfer(msg.sender, basic);
    }

    function setProtect(bool _protect) external onlyOwner {
        protect = _protect;
    }

    function tokenTranfer(IERC20 token, uint256 amount) external onlyOwner {
        token.safeTransfer(msg.sender, amount);
    }

    function nftTranfer(IERC721 nft, uint256 tokenId) external onlyOwner {
        nft.safeTransferFrom(address(this), msg.sender, tokenId);
    }
}
