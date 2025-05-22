//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./ICash.sol";
import "./IVault.sol";
import "./IVaultManager.sol";

import "./GovGuard.sol";

contract VaultManager is GovGuard, IVaultManager {
    using SafeERC20 for IERC20;

    address public immutable dai; // = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public immutable usds; // = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address public immutable usdc; // = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address public immutable cash;
    address public immutable sCash;

    address public treasury;
    address public manager;

    address[] public allowedVaults;
    mapping(address => bool) public isAllowedVaults;

    uint256 public maxMintAmount;
    uint256 public totalMintedCashAmount;
    uint256 public lastEarnTs;

    event Mint(
        address user,
        uint256 cashAmount,
        address token,
        uint256 tokenAmount
    );
    event Redeem(
        address user,
        uint256 cashAmount,
        address token,
        uint256 tokenAmount
    );
    event RedeemByVault(address user, uint256 amount, address vault);

    constructor(
        address dai_,
        address usds_,
        address usdc_,
        address cash_,
        address sCash_,
        address treasury_,
        address manager_,
        address gov_,
        address guard_
    ) GovGuard(gov_, guard_) {
        dai = dai_;
        usds = usds_;
        usdc = usdc_;
        cash = cash_;
        sCash = sCash_;
        treasury = treasury_;
        manager = manager_;
    }

    function mint(address token, uint tokenAmount) external {
        require(accept(token), "token not accepted");

        uint cashAmount = tokenAmount;
        if (token == usdc) {
            cashAmount = tokenAmount * 1e12;
        }

        require(
            totalMintedCashAmount + cashAmount <= maxMintAmount,
            "exceed max amount"
        );
        IERC20(token).safeTransferFrom(msg.sender, address(this), tokenAmount);

        ICash(cash).mint(msg.sender, cashAmount);
        totalMintedCashAmount += cashAmount;

        emit Mint(msg.sender, cashAmount, token, tokenAmount);
    }

    function redeem(address toToken, uint cashAmount) external {
        ICash(cash).burn(msg.sender, cashAmount);
        totalMintedCashAmount -= cashAmount;
        uint tokenAmount = (cashAmount * 9995) / 10000; // 0.05% redeem fee
        if (toToken == usdc) {
            tokenAmount = tokenAmount / 1e12;
        }
        IERC20(toToken).safeTransfer(msg.sender, tokenAmount);
        emit Redeem(msg.sender, cashAmount, toToken, tokenAmount);
    }

    function redeemByVault(address user, uint amount) external override {
        require(isAllowedVaults[msg.sender], "not allowed vault");
        ICash(cash).burn(user, amount);
        totalMintedCashAmount -= amount;
        emit RedeemByVault(user, amount, msg.sender);
    }

    function earn() external {
        require(lastEarnTs + 3600 <= block.timestamp, "too often");
        uint earnBal = tvl() - totalMintedCashAmount;
        require(earnBal * 2000 <= totalMintedCashAmount || msg.sender == guard, "earn error");


        if (earnBal > 0) {
            uint toTreasury = earnBal / 5; // 20% for treasury
            uint toManager = earnBal / 10; // 10% for manager
            uint toSCash = earnBal - toTreasury - toManager; // 70% for staker

            ICash(cash).mint(sCash, toSCash);
            ICash(cash).mint(treasury, toTreasury);
            ICash(cash).mint(manager, toManager);

            totalMintedCashAmount += earnBal;
        }
        lastEarnTs = block.timestamp;
    }

    function setTreasury(address treasury_) external onlyGov {
        treasury = treasury_;
    }

    function setManager(address manager_) external onlyGuard {
        manager = manager_;
    }

    function setMaxMintAmount(uint256 amount_) external onlyGuard {
        maxMintAmount = amount_;
    }

    function addVault(address vault) external onlyGov {
        require(!isAllowedVaults[vault], "already added");
        allowedVaults.push(vault);
        isAllowedVaults[vault] = true;
    }

    function removeVault(address vault) external onlyGuard {
        require(
            isAllowedVaults[vault] && IVault(vault).tvl() == 0,
            "remove vault error"
        );
        address lastVault = allowedVaults[allowedVaults.length - 1];
        for (uint i = 0; i < allowedVaults.length - 1; i++) {
            if (allowedVaults[i] == vault) {
                allowedVaults[i] = lastVault;
                break;
            }
        }
        allowedVaults.pop();
        isAllowedVaults[vault] = false;
    }

    function deposit(
        address vault,
        address token,
        uint amount
    ) external onlyGuard {
        require(
            isAllowedVaults[vault] && IVault(vault).accept(token),
            "deposit to vault error"
        );
        IERC20(token).safeTransfer(vault, amount);
    }

    function skim(address token, uint amount) external onlyGuard {
        require(!accept(token), "skim error");
        IERC20(token).safeTransfer(manager, amount);
    }

    function tvl() public view returns (uint256 v) {
        v = IERC20(dai).balanceOf(address(this));
        v += IERC20(usds).balanceOf(address(this));
        v += IERC20(usdc).balanceOf(address(this)) * 1e12;
        for (uint i = 0; i < allowedVaults.length; i++) {
            v += IVault(allowedVaults[i]).tvl();
        }
    }

    function accept(address token) public view returns (bool) {
        return token == dai || token == usds || token == usdc;
    }
}
