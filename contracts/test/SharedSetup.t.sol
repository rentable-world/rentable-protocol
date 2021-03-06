// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.7;

import {DSTest} from "ds-test/test.sol";
import {Vm} from "forge-std/Vm.sol";

import {TestHelper} from "./TestHelper.t.sol";

import {TestNFT} from "./mocks/TestNFT.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {DummyERC1155} from "./mocks/DummyERC1155.sol";
import {IRentable} from "../interfaces/IRentable.sol";
import {BaseTokenInitializable} from "../tokenization/BaseTokenInitializable.sol";

import {Rentable} from "../Rentable.sol";
import {ORentable} from "../tokenization/ORentable.sol";
import {WRentable} from "../tokenization/WRentable.sol";

import {SimpleWallet} from "../wallet/SimpleWallet.sol";
import {WalletFactory} from "../wallet/WalletFactory.sol";
import {DummyCollectionLibrary} from "./mocks/DummyCollectionLibrary.sol";

import {RentableTypes} from "./../RentableTypes.sol";
import {IRentableEvents} from "./../interfaces/IRentableEvents.sol";

import {ImmutableAdminTransparentUpgradeableProxy} from "../upgradability/ImmutableAdminTransparentUpgradeableProxy.sol";
import {ImmutableAdminUpgradeableBeaconProxy} from "../upgradability/ImmutableAdminUpgradeableBeaconProxy.sol";

import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

abstract contract SharedSetup is DSTest, TestHelper, IRentableEvents {
    Vm public constant vm = Vm(HEVM_ADDRESS);

    address user;

    address governance;
    address operator;
    address payable feeCollector;

    WETH weth;

    DummyCollectionLibrary dummyLib;

    TestNFT testNFT;
    DummyERC1155 dummy1155;

    Rentable rentableLogic;
    ProxyAdmin proxyAdmin;

    Rentable rentable;
    ORentable orentable;
    WRentable wrentable;

    UpgradeableBeacon obeacon;
    ORentable orentableLogic;
    UpgradeableBeacon wbeacon;
    WRentable wrentableLogic;

    SimpleWallet simpleWalletLogic;
    UpgradeableBeacon simpleWalletBeacon;
    WalletFactory walletFactory;

    address paymentTokenAddress = address(0);
    uint256 paymentTokenId = 0;
    uint256 tokenId = 123;

    address[] paymentTokens;

    address[] privateRenters;
    address privateRenter;

    uint256 pricePerSecond;

    uint256 minTimeDuration;
    uint256 maxTimeDuration;

    address renter;

    modifier paymentTokensCoverage() {
        for (uint256 i = 0; i < paymentTokens.length; i++) {
            paymentTokenAddress = paymentTokens[i];
            _;
        }
    }

    modifier privateRentersCoverage() {
        for (uint256 i = 0; i < privateRenters.length; i++) {
            privateRenter = privateRenters[i];
            _;
        }
    }

    modifier protocolFeeCoverage() {
        // 0%
        vm.prank(governance);
        rentable.setFee(0);
        _;

        // 2.5%
        vm.prank(governance);
        rentable.setFee(250);
        _;

        // 5%
        vm.prank(governance);
        rentable.setFee(500);
        _;

        // Reset
        vm.prank(governance);
        rentable.setFee(0);
    }

    function setUp() public virtual {
        user = getNewAddress();
        governance = getNewAddress();
        operator = getNewAddress();
        feeCollector = payable(getNewAddress());

        vm.startPrank(governance);

        dummyLib = new DummyCollectionLibrary(false);

        weth = new WETH();

        testNFT = new TestNFT();

        dummy1155 = new DummyERC1155();

        rentableLogic = new Rentable(governance, address(0));
        proxyAdmin = new ProxyAdmin();
        rentable = Rentable(
            address(
                new ImmutableAdminTransparentUpgradeableProxy(
                    address(rentableLogic),
                    address(proxyAdmin),
                    abi.encodeWithSelector(
                        Rentable.initialize.selector,
                        governance,
                        operator
                    )
                )
            )
        );

        orentableLogic = new ORentable(
            address(testNFT),
            address(0),
            address(0)
        );

        obeacon = new UpgradeableBeacon(address(orentableLogic));

        orentable = ORentable(
            address(
                new ImmutableAdminUpgradeableBeaconProxy(
                    address(obeacon),
                    address(proxyAdmin),
                    abi.encodeWithSelector(
                        BaseTokenInitializable.initialize.selector,
                        address(testNFT),
                        governance,
                        address(rentable)
                    )
                )
            )
        );

        rentable.setORentable(address(testNFT), address(orentable));

        wrentableLogic = new WRentable(
            address(testNFT),
            address(0),
            address(0)
        );

        wbeacon = new UpgradeableBeacon(address(wrentableLogic));

        wrentable = WRentable(
            address(
                new ImmutableAdminUpgradeableBeaconProxy(
                    address(wbeacon),
                    address(proxyAdmin),
                    abi.encodeWithSelector(
                        BaseTokenInitializable.initialize.selector,
                        address(testNFT),
                        governance,
                        address(rentable)
                    )
                )
            )
        );

        rentable.setWRentable(address(testNFT), address(wrentable));

        simpleWalletLogic = new SimpleWallet(address(rentable), address(0));
        simpleWalletBeacon = new UpgradeableBeacon(address(simpleWalletLogic));
        walletFactory = new WalletFactory(address(simpleWalletBeacon));

        rentable.setWalletFactory(address(walletFactory));

        rentable.enablePaymentToken(address(0));
        rentable.enablePaymentToken(address(weth));
        rentable.enable1155PaymentToken(address(dummy1155));

        rentable.setFeeCollector(feeCollector);

        rentable.setLibrary(address(testNFT), address(dummyLib));

        initPaymentTokens();

        vm.stopPrank();
    }

    function initPaymentTokens() internal {
        paymentTokens = new address[](3);
        paymentTokens.push(address(0));
        paymentTokens.push(address(weth));
        paymentTokens.push(address(dummy1155));
    }

    function initPrivateRenters() internal {
        privateRenters = new address[](2);
        privateRenters.push(address(0));
        privateRenters.push(getNewAddress());
    }

    function prepareTestDeposit() internal {
        testNFT.mint(user, ++tokenId);
    }

    function depositAndApprove(
        address _user,
        uint256 value,
        address _paymentToken,
        uint256 _paymentTokenId
    ) public {
        vm.deal(_user, value);
        if (_paymentToken == address(weth)) {
            weth.deposit{value: value}();
            weth.approve(address(rentable), ~uint256(0));
        } else if (_paymentToken == address(dummy1155)) {
            dummy1155.deposit{value: value}(_paymentTokenId);
            dummy1155.setApprovalForAll(address(rentable), true);
        }
    }

    function getBalance(
        address _user,
        address paymentToken,
        uint256 _paymentTokenId
    ) public view returns (uint256) {
        if (paymentToken == address(weth)) {
            return weth.balanceOf(_user);
        } else if (paymentToken == address(dummy1155)) {
            return dummy1155.balanceOf(_user, _paymentTokenId);
        } else {
            return _user.balance;
        }
    }

    function _prepareRent() internal {
        _prepareRent(getNewAddress());
    }

    function _prepareRent(address _renter) internal {
        maxTimeDuration = 10 days;
        pricePerSecond = 0.001 ether;

        renter = _renter;
        prepareTestDeposit();

        testNFT.safeTransferFrom(
            user,
            address(rentable),
            tokenId,
            abi.encode(
                RentableTypes.RentalConditions({
                    minTimeDuration: minTimeDuration,
                    maxTimeDuration: maxTimeDuration,
                    pricePerSecond: pricePerSecond,
                    paymentTokenId: paymentTokenId,
                    paymentTokenAddress: paymentTokenAddress,
                    privateRenter: privateRenter
                })
            )
        );
    }
}
