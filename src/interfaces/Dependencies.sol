// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title  Wrapped M Token Like interface developed by M^0 Labs.
 * @author 0xt0n1
 */
interface IWrappedMTokenLike {
    function startEarningFor(address account) external;

    function claimFor(address account_) external returns (uint240);
}

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IERC721Like {
    function ownerOf(uint256 tokenId) external view returns (address);
}
