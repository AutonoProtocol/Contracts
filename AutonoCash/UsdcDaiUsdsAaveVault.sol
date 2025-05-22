//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IVault.sol";
import "./IVaultManager.sol";
import "./IAavePool.sol";

import "./GovGuard.sol";

contract UsdcDaiUsdsAaveVault is GovGuard, IVault {
    address public constant dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant usds = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address public constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address public constant aavePool =
        0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public constant aaveIncentive =
        0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb;

    address public constant aDai = 0x018008bfb33d285247A21d44E50697654f754e63;
    address public constant aUsds = 0x32a6268f9Ba3642Dda7892aDd74f1D34469A4259;
    address public constant aUsdc = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c;

    address public immutable vaultManager;

    constructor(
        address gov_,
        address guard_,
        address vaultManger_
    ) GovGuard(gov_, guard_) {
        vaultManager = vaultManger_;
    }

    function deposit(address token, uint256 amount) external onlyGuard {
        IERC20(token).approve(aavePool, amount);
        IAavePool(aavePool).supply(token, amount, address(this), 0);
    }

    function withdraw(address token, uint256 amount) external onlyGuard {
        IAavePool(aavePool).withdraw(token, amount, address(this));
    }

    function claimReward(
        address[] memory assets,
        address reward
    ) external onlyGuard {
        IAaveIncentive(aaveIncentive).claimRewards(
            assets,
            type(uint256).max,
            address(this),
            reward
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

    function tokenExchange(
        address from,
        address to,
        uint amount
    ) external onlyGuard {
        require(accept(from) && accept(to) && from != to, "error");
        uint fromAmount = from == usdc ? amount / 1e12 : amount;
        uint toAmount = to == usdc ? amount / 1e12 : amount;
        IERC20(to).transferFrom(msg.sender, address(this), toAmount);
        IERC20(from).transfer(msg.sender, fromAmount);
    }

    function redeem(address toToken, uint cashAmount) external {
        require(accept(toToken), "error");
        IVaultManager(vaultManager).redeemByVault(msg.sender, cashAmount);
        uint tokenAmount = (cashAmount * 9995) / 10000; // 0.05% redeem fee
        if (toToken == usdc) {
            tokenAmount = tokenAmount / 1e12;
        }
        uint tokenBal = IERC20(toToken).balanceOf(address(this));
        if (tokenBal < tokenAmount) {
            IAavePool(aavePool).withdraw(
                toToken,
                tokenAmount - tokenBal,
                address(this)
            );
        }
        IERC20(toToken).transfer(msg.sender, tokenAmount);
    }

    function accept(address token) public pure override returns (bool) {
        return token == dai || token == usds || token == usdc;
    }

    function tvl() external view override returns (uint256 v) {
        v =
            IERC20(dai).balanceOf(address(this)) +
            IERC20(aDai).balanceOf(address(this));
        v +=
            IERC20(usds).balanceOf(address(this)) +
            IERC20(aUsds).balanceOf(address(this));
        v +=
            (IERC20(usdc).balanceOf(address(this)) +
                IERC20(aUsdc).balanceOf(address(this))) *
            1e12;
    }
}
