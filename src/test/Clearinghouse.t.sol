// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";
import {UserFactory} from "test/lib/UserFactory.sol";

//import {MockERC20, MockGohm, MockStaking} from "test/mocks/OlympusMocks.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockERC4626} from "solmate/test/utils/mocks/MockERC4626.sol";

import {RolesAdmin, Kernel, Actions} from "olympus-v3/policies/RolesAdmin.sol";
import {OlympusRoles, ROLESv1} from "olympus-v3/modules/ROLES/OlympusRoles.sol";
import {OlympusMinter, MINTRv1} from "olympus-v3/modules/MINTR/OlympusMinter.sol";
import {OlympusTreasury, TRSRYv1} from "olympus-v3/modules/TRSRY/OlympusTreasury.sol";
//import {Actions} from "olympus-v3/Kernel.sol";

import {ClearingHouse, Cooler, CoolerFactory} from "src/ClearingHouse.sol";

// Tests for ClearingHouse
//
// ClearingHouse Setup and Permissions
// [ ] configureDependencies
// [ ] requestPermissions
//
// ClearingHouse Functions
// [ ] rebalance
//     [ ] can't rebalance faster than the funding cadence
//     [ ] Treasury approvals for the clearing house are correct
//     [ ] if necessary, sends excess DSR funds back to the Treasury
// [ ] sweep
//     [ ] excess DAI is deposited into DSR
// [ ] defund
//     [ ] only "cooler_overseer" can call
//     [ ] sends input ERC20 token back to the Treasury
// [ ] lend
//     [ ] only lend to coolers issued by coolerFactory
//     [ ] only collateral = gOHM and only debt = DAI
//     [ ] loan request is logged
//     [ ] user and cooler new gOHM balances are correct
//     [ ] user and Treasury new DAI balances are correct
// [ ] roll
//     [ ] user and cooler new gOHM balances are correct
// [ ] burn
//     [ ] OHM supply is properly reduced

contract MockStaking {
    function unstake(
        address,
        uint256 amount,
        bool,
        bool
    ) external returns (uint256) {
        return amount;
    }
}

contract ClearingHouseTest is Test {
    MockERC20 internal gohm;
    MockERC20 internal ohm;
    MockERC20 internal dai;
    MockERC4626 internal sdai;

    Kernel public kernel;
    OlympusRoles internal ROLES;
    OlympusMinter internal MINTR;
    OlympusTreasury internal TRSRY;
    RolesAdmin internal rolesAdmin;
    ClearingHouse internal clearinghouse;
    CoolerFactory internal factory;
    Cooler internal testCooler;

    address internal randomWallet;
    address internal overseer;
    uint256 internal initialSDai;

    // Parameter Bounds
    uint256 public constant INTEREST_RATE = 5e15; // 0.5%
    uint256 public constant LOAN_TO_COLLATERAL = 3000 * 1e18; // 3,000
    uint256 public constant DURATION = 121 days; // Four months
    uint256 public constant FUND_CADENCE = 7 days; // One week
    uint256 public constant FUND_AMOUNT = 18 * 1e24; // 18 million

    function setUp() public {
        address[] memory users = (new UserFactory()).create(2);
        randomWallet = users[0];
        overseer = users[1];

        MockStaking staking = new MockStaking();
        factory = new CoolerFactory();

        ohm = new MockERC20("olympus", "OHM", 9);
        gohm = new MockERC20("olympus", "gOHM", 18);
        dai = new MockERC20("dai", "DAI", 18);
        sdai = new MockERC4626(dai, "sDai", "sDAI");

        kernel = new Kernel(); // this contract will be the executor

        TRSRY = new OlympusTreasury(kernel);
        MINTR = new OlympusMinter(kernel, address(ohm));
        ROLES = new OlympusRoles(kernel);

        clearinghouse = new ClearingHouse(
            address(gohm),
            address(staking),
            address(sdai),
            address(factory),
            address(kernel)
        );
        rolesAdmin = new RolesAdmin(kernel);

        kernel.executeAction(Actions.InstallModule, address(TRSRY));
        kernel.executeAction(Actions.InstallModule, address(MINTR));
        kernel.executeAction(Actions.InstallModule, address(ROLES));

        kernel.executeAction(Actions.ActivatePolicy, address(clearinghouse));
        kernel.executeAction(Actions.ActivatePolicy, address(rolesAdmin));

        /// Configure access control
        rolesAdmin.grantRole("cooler_overseer", overseer);

        // Setup clearinghouse initial conditions
        uint mintAmount = 36e24; // Fund 18 million

        dai.mint(address(TRSRY), mintAmount);
        //dai.approve(address(sdai), dai.balanceOf(address(this)));
        //sdai.deposit(dai.balanceOf(address(this)), address(TRSRY));

        // Initial rebalance, fund clearinghouse and set
        // fundTime to current timestamp
        clearinghouse.rebalance();
        testCooler = Cooler(factory.generate(gohm, dai));

        gohm.mint(overseer, mintAmount);
    }

    function test_LendToCooler() public {}

    function test_RollLoan() public {}

    function test_Rebalance() public {
        uint last = block.timestamp;

        // clearinghouse should have nothing
        uint sdaiBal = sdai.balanceOf(address(clearinghouse));
        assertEq(sdaiBal, 0);

        // No funds should be released -- already happened in setUp()
        console.log("WTFFFFF");
        console.log("TRSRY DAI BALANCE: ", dai.balanceOf(address(TRSRY)));
        clearinghouse.rebalance();
        assertTrue(sdaiBal == sdai.balanceOf(address(clearinghouse)));

        /*

        // Funds equal to second index in array should be released
        clearinghouse.rebalance();
        assertTrue(
            balance + budget[1] == dai.balanceOf(address(clearinghouse))
        );

        balance = dai.balanceOf(address(clearinghouse));
        last = clearinghouse.lastFunded();

        // Funds equal to third index in array should be released
        clearinghouse.fund(last + clearinghouse.cadence() + 1);
        assertTrue(
            balance + budget[2] == dai.balanceOf(address(clearinghouse))
        );
        */
    }

    function testRevert_RebalanceEarly() public {
        vm.expectRevert(ClearingHouse.TooEarlyToFund.selector);
    }

    // Should be able to rebalance multiple times if past due
    function test_RebalancePastDue() public {}

    function test_Sweep() public {}

    function test_Defund() public {}

    function test_DefundOnlyOverseer() public {}

    function test_BurnExcess() public {}
}
