// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {DSTest} from "ds-test/test.sol";
import {CheatCodes} from "./SharedSetup.t.sol";

import {TestImplLogicV1} from "./mocks/TestImplLogicV1.sol";
import {TestImplLogicV2} from "./mocks/TestImplLogicV2.sol";
import {ImmutableAdminTransparentUpgradeableProxy} from "../upgradability/ImmutableAdminTransparentUpgradeableProxy.sol";
import {ProxyAdmin, TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract ImmutableAdminTransparentUpgradeableProxyTest is DSTest {
    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    uint256 initialTestNumber;

    TestImplLogicV1 logicV1;

    ImmutableAdminTransparentUpgradeableProxy proxy;
    ProxyAdmin proxyAdmin;
    address owner;

    function setUp() public {
        owner = cheats.addr(1);

        cheats.startPrank(owner);

        // Deploy logic
        logicV1 = new TestImplLogicV1();
        logicV1.init(0);

        // Deploy proxy

        // 1. deploy admin
        proxyAdmin = new ProxyAdmin();

        // 2.prepare init data
        initialTestNumber = 4;
        bytes memory _data = abi.encodeWithSelector(
            TestImplLogicV1.init.selector,
            initialTestNumber
        );

        // 3. deploy proxy
        proxy = new ImmutableAdminTransparentUpgradeableProxy(
            address(logicV1),
            address(proxyAdmin),
            _data
        );

        cheats.stopPrank();
    }

    function testProxySetup() public {
        // proxy admin is the admin
        assertEq(
            address(
                proxyAdmin.getProxyAdmin(
                    TransparentUpgradeableProxy(payable(address(proxy)))
                )
            ),
            address(proxyAdmin)
        );

        // only owner can transfer ownership
        address anotherUser = cheats.addr(2);
        cheats.startPrank(anotherUser);
        cheats.expectRevert(bytes("Ownable: caller is not the owner"));
        proxyAdmin.transferOwnership(anotherUser);
        cheats.stopPrank();

        cheats.startPrank(owner);
        proxyAdmin.transferOwnership(anotherUser);
        assertEq(proxyAdmin.owner(), anotherUser);
        cheats.stopPrank();

        // proxy implementation is the v1
        assertEq(
            proxyAdmin.getProxyImplementation(
                TransparentUpgradeableProxy(payable(address(proxy)))
            ),
            address(logicV1)
        );

        // data proxy different data logic
        assertTrue(
            logicV1.getTestNumber() !=
                TestImplLogicV1(address(proxy)).getTestNumber()
        );
    }

    function testUpgradeProxy() public {
        // deploy new logic
        TestImplLogicV2 logicV2 = new TestImplLogicV2();
        logicV2.init(initialTestNumber);

        // change implementation to the proxy
        // only proxyadmin can
        address anotherUser = cheats.addr(2);
        cheats.startPrank(anotherUser);
        cheats.expectRevert(bytes(""));
        proxy.upgradeTo(address(logicV2));
        cheats.stopPrank();

        // upgrade as proxyadmin
        cheats.startPrank(owner);
        proxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(proxy))),
            address(logicV2)
        );
        cheats.stopPrank();

        // check is still initialized
        cheats.expectRevert(
            bytes("Initializable: contract is already initialized")
        );
        TestImplLogicV2(address(proxy)).init(5);
        // and new logic is in place
        assertEq(
            TestImplLogicV2(address(proxy)).getTestNumber(),
            initialTestNumber * 2
        );
    }
}