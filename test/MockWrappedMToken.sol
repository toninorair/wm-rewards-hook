// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { MockERC20 } from "solmate/src/test/utils/mocks/MockERC20.sol";

contract MockWrappedMToken is MockERC20 {
    address public hook;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) MockERC20(name_, symbol_, decimals_) {}

    function startEarningFor(address) external {}

    function setHook(address hook_) external {
        hook = hook_;
    }

    function claimFor(address earner_) external returns (uint240) {
        uint240 rewards_ = 10e6;

        _mint(hook, rewards_);

        return rewards_;
    }
}
