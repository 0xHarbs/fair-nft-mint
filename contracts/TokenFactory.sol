//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenFactory is ERC20, Ownable {
    mapping(address => uint256) public rewards;

    constructor() ERC20("TokenName", "TICKER") {}

    function updateReward() external {}

    function getReward() external {}

    function updateRewardOnMint() external {}
}
