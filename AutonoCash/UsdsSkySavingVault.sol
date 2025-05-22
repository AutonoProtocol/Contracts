//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IVault.sol";
import "./IVaultManager.sol";
import "./GovGuard.sol";

interface ISusds {
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares);

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    function convertToAssets(uint256 shares) external view returns (uint256);
}

contract UsdsSkySavingVault is GovGuard, IVault {
    address public constant usds = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address public constant sUsds = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;

    address public immutable vaultManager;

    constructor(
        address gov_,
        address guard_,
        address vaultManger_
    ) GovGuard(gov_, guard_) {
        vaultManager = vaultManger_;
    }

    function deposit(uint amount) external onlyGuard {
        IERC20(usds).approve(sUsds, amount);
        ISusds(sUsds).deposit(amount, address(this));
    }

    function withdraw() external onlyGuard {
        ISusds(sUsds).redeem(
            IERC20(sUsds).balanceOf(address(this)),
            address(this),
            address(this)
        );
    }

    function transferTokens(address token, uint amount) external onlyGuard {
        require(accept(token), "error");
        IERC20(token).transfer(vaultManager, amount);
    }

    function skim(address token, uint amount) external onlyGuard {
        require(!accept(token), "skim");
        IERC20(token).transfer(guard, amount);
    }

    function redeem(address toToken, uint cashAmount) external {
        require(toToken == usds, "error");
        IVaultManager(vaultManager).redeemByVault(msg.sender, cashAmount);
        uint tokenAmount = (cashAmount * 9995) / 10000; // 0.05% redeem fee
        uint tokenBal = IERC20(usds).balanceOf(address(this));
        if (tokenBal < tokenAmount) {
            ISusds(sUsds).withdraw(
                tokenAmount - tokenBal,
                address(this),
                address(this)
            );
        }
        IERC20(toToken).transfer(msg.sender, tokenAmount);
    }

    function accept(address token) public pure override returns (bool) {
        return token == usds;
    }

    function tvl() external view override returns (uint256 v) {
        v += IERC20(usds).balanceOf(address(this));
        v += ISusds(sUsds).convertToAssets(
            IERC20(sUsds).balanceOf(address(this))
        );
    }
}
