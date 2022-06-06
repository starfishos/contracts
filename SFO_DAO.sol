// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SFO_DAO is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    using EnumerableSet for EnumerableSet.UintSet;

    uint16 constant noneExist = 65535;

    struct Dao {
        string[] params;
        address token;
        address lp;
        uint32 memberCount;
        bool status;
    }
    struct Councli {
        address addr;
        uint256 frozen;
        bool status;
    }
    Dao[] public daos;

    mapping(uint16 => Councli[]) public daoCounclis;

    event LogDaoAdd(address indexed addr, address indexed token, uint16 indexed daoAt);
    event LogDaoEdit(address indexed addr, uint16 indexed daoAt);
    event LogDaoRemove(address indexed addr, uint16 indexed daoAt);
    event LogCountApply(address indexed addr, uint16 indexed daoAt, uint16 indexed councliAt);
    event LogCountQuit(address indexed addr, uint16 indexed daoAt, uint16 indexed councliAt);
    event LogProposalAdd(address indexed addr, uint16 indexed daoAt, uint16 indexed proposalAt);
    event LogProposalEdit(address indexed addr, uint16 indexed daoAt, uint16 indexed proposalAt);
    event LogProposalFinish(address indexed addr, uint16 indexed daoAt, uint16 indexed proposalAt);
    event LogUserDaoJoin(address indexed addr, uint16 indexed daoAt);
    event LogUserDaoQuit(address indexed addr, uint16 indexed daoAt);
    event LogUserVote(address indexed addr, uint16 indexed daoAt, uint16 indexed proposalAt);
    event LogVoteFinish(address indexed addr, uint16 indexed daoAt, uint16 indexed proposalAt);

    function daoAdd(
        string[] memory params,
        address token,
        address lp
    ) external nonReentrant {
        require(token != address(0), "zero address not allow");
        require(!daoExist(token), "Dao exist.");
        uint256 frozenAmount = IERC20(token).totalSupply() / 100;
        IERC20(token).safeTransferFrom(msg.sender, address(this), frozenAmount);
        daos.push(Dao({params: params, token: token, lp: lp, memberCount: 1, status: true}));
        daoCounclis[uint16(daos.length - 1)].push(Councli({addr: msg.sender, frozen: frozenAmount, status: true}));
        userDao[msg.sender][uint16(daos.length - 1)] = true;
        emit LogDaoAdd(msg.sender, token, uint16(daos.length) - 1);
    }

    function daoEdit(
        uint16 daoAt,
        string[] memory params,
        address token // address lp
    ) external {
        require(token != address(0), "zero address not allow");
        require(daoExist(token), "Dao not exist.");
        require(userCouncli(daoAt, msg.sender), "forbidden");

        daos[daoAt].params = params;
        emit LogDaoEdit(msg.sender, daoAt);
    }

    function daoList() external view returns (Dao[] memory) {
        return daos;
    }

    function daoExist(address token) public view returns (bool) {
        for (uint32 i = 0; i < daos.length; i++) {
            if (daos[i].token == token) {
                return true;
            }
        }
        return false;
    }

    function daoRemove(uint16 daoAt) external onlyOwner {
        daos[daoAt].status = false;
        emit LogDaoRemove(owner(), daoAt);
    }

    function daoCouncliList(uint16 daoAt) external view returns (Councli[] memory) {
        return daoCounclis[daoAt];
    }

    function councliAssign(uint16 daoAt, address[] memory addrs) external onlyOwner {
        for (uint16 i = 0; i < addrs.length; i++) {
            uint16 councliAt_ = councliAt(daoAt, addrs[i]);
            if (councliAt_ == noneExist) {
                daoCounclis[daoAt].push(Councli({addr: addrs[i], frozen: 0, status: true}));
            } else if (!daoCounclis[daoAt][councliAt_].status) {
                daoCounclis[daoAt][councliAt_].status = true;
                daoCounclis[daoAt][councliAt_].frozen = 0;
            }
            if (!userDao[msg.sender][daoAt]) {
                userDao[msg.sender][daoAt] = true;
                daos[daoAt].memberCount++;
            }
        }
    }

    function councliApply(uint16 daoAt) external {
        uint16 councliAt_ = councliAt(daoAt, msg.sender);
        require(councliAt_ == noneExist || !daoCounclis[daoAt][councliAt_].status, "You are already the councli.");

        uint256 frozenAmount = IERC20(daos[daoAt].token).totalSupply() / 1000;
        IERC20(daos[daoAt].token).safeTransferFrom(msg.sender, address(this), frozenAmount);
        if (councliAt_ == noneExist) {
            daoCounclis[daoAt].push(Councli({addr: msg.sender, frozen: frozenAmount, status: true}));
        } else {
            daoCounclis[daoAt][councliAt_].frozen = frozenAmount;
            daoCounclis[daoAt][councliAt_].status = true;
        }
        if (!userDao[msg.sender][daoAt]) {
            userDao[msg.sender][daoAt] = true;
            daos[daoAt].memberCount++;
        }
        emit LogCountApply(msg.sender, daoAt, councliAt(daoAt, msg.sender));
    }

    function councliQuit(uint16 daoAt) external {
        uint16 councliAt_ = councliAt(daoAt, msg.sender);
        require(councliAt_ != noneExist && daoCounclis[daoAt][councliAt_].status, "You are not the councli.");
        daoCounclis[daoAt][councliAt_].status = false;
        IERC20(daos[daoAt].token).safeTransfer(msg.sender, daoCounclis[daoAt][councliAt_].frozen);
        daoCounclis[daoAt][councliAt_].frozen = 0;
        emit LogCountQuit(msg.sender, daoAt, councliAt_);
    }

    function councliAt(uint16 daoAt, address addr) public view returns (uint16) {
        for (uint16 i = 0; i < daoCounclis[daoAt].length; i++) {
            if (daoCounclis[daoAt][i].addr == addr) {
                return i;
            }
        }
        return noneExist;
    }

    function lpToTokenPrice(address lp, address token) public view returns (uint256) {
        return (IERC20(token).balanceOf(lp) * 2e18) / IERC20(lp).totalSupply();
    }

    struct Proposal {
        uint16 daoAt;
        string[] name_desc;
        uint256[] uintParams;
        bool mutilOption;
        string[] options;
        uint256[] votes;
        uint256 totalVote;
        address initiate;
        uint256 frozenAmount;
        uint8 status;
    }
    struct Vote {
        address voter;
        uint256 lpAmount;
        uint256 tokenAmount;
        uint8[] options;
        uint256[] amounts;
        bool status;
    }
    mapping(uint16 => Proposal[]) public daoProposals;
    mapping(uint16 => mapping(uint16 => Vote[])) private proposalVotes;

    function proposalAdd(
        uint16 daoAt,
        string[] memory strParams,
        uint256[] memory uintParams,
        bool mutilOption,
        string[] memory options
    ) external {
        uint16 councliAt_ = councliAt(daoAt, msg.sender);
        uint256 frozenAmount = 0;
        if (councliAt_ == noneExist || daoCounclis[daoAt][councliAt_].status == false) {
            frozenAmount = IERC20(daos[daoAt].token).totalSupply() / 2000;
            IERC20(daos[daoAt].token).safeTransferFrom(msg.sender, address(this), frozenAmount);
        }
        if (uintParams[2] != 0) {
            IERC20(daos[daoAt].token).safeTransferFrom(msg.sender, address(this), uintParams[2]);
        }
        daoProposals[daoAt].push(
            Proposal({daoAt: daoAt, name_desc: strParams, uintParams: uintParams, mutilOption: mutilOption, options: options, votes: new uint256[](options.length), totalVote: 0, initiate: msg.sender, frozenAmount: frozenAmount, status: 10})
        );
        emit LogProposalAdd(msg.sender, daoAt, councliAt(daoAt, msg.sender));
    }

    function proposalEdit(
        uint16 daoAt,
        uint16 proposalAt,
        string[] memory strParams,
        uint256[] memory uintParams,
        bool mutilOption,
        string[] memory options
    ) external {
        require(block.timestamp < daoProposals[daoAt][proposalAt].uintParams[3], "Proposal already start.");
        require(daoProposals[daoAt][proposalAt].initiate == msg.sender, "You are not the initiate.");
        require(daoProposals[daoAt][proposalAt].uintParams[2] == uintParams[2], "Reward can not edit.");
        daoProposals[daoAt][proposalAt].name_desc = strParams;
        daoProposals[daoAt][proposalAt].uintParams = uintParams;
        daoProposals[daoAt][proposalAt].mutilOption = mutilOption;
        daoProposals[daoAt][proposalAt].options = options;
        emit LogProposalEdit(msg.sender, daoAt, proposalAt);
    }

    function proposalFinsh(uint16 daoAt, uint16 proposalAt) external {
        require(block.timestamp >= daoProposals[daoAt][proposalAt].uintParams[4], "Proposal not end.");
        require(daoProposals[daoAt][proposalAt].status != 20, "Proposal already end");
        daoProposals[daoAt][proposalAt].status = 20;

        if (daoProposals[daoAt][proposalAt].frozenAmount != 0) {
            IERC20(daos[daoAt].token).safeTransfer(daoProposals[daoAt][proposalAt].initiate, daoProposals[daoAt][proposalAt].frozenAmount);
        }

        if (daoProposals[daoAt][proposalAt].totalVote == 0 && daoProposals[daoAt][proposalAt].uintParams[2] != 0) {
            IERC20(daos[daoAt].token).safeTransfer(daoProposals[daoAt][proposalAt].initiate, daoProposals[daoAt][proposalAt].uintParams[2]);
        }
        emit LogProposalFinish(msg.sender, daoAt, proposalAt);
    }

    function proposalRemove(uint16 daoAt, uint16 proposalAt) external onlyOwner {
        daoProposals[daoAt][proposalAt].status = 40;
    }

    function prosalList(uint16 daoAt) external view returns (Proposal[] memory) {
        return daoProposals[daoAt];
    }

    mapping(address => mapping(uint16 => bool)) public userDao;
    mapping(address => EnumerableSet.UintSet) private userVoteRecord;

    function daoJoin(uint16 daoAt) external {
        require(!userDao[msg.sender][daoAt], "You are already the member.");
        userDao[msg.sender][daoAt] = true;
        daos[daoAt].memberCount++;
        emit LogUserDaoJoin(msg.sender, daoAt);
    }

    function userDaoList(address addr) external view returns (bool[] memory) {
        bool[] memory userDaos = new bool[](daos.length);
        for (uint16 i = 0; i < daos.length; i++) {
            if (userDao[addr][i]) {
                userDaos[i] = true;
            }
        }
        return userDaos;
    }

    function daoQuit(uint16 daoAt) external {
        require(userDao[msg.sender][daoAt], "You are not the member.");
        userDao[msg.sender][daoAt] = false;
        daos[daoAt].memberCount--;
        emit LogUserDaoQuit(msg.sender, daoAt);
    }

    function vote(
        uint16 daoAt,
        uint16 proposalAt,
        bool lp,
        uint8[] memory options,
        uint256[] memory amounts
    ) external nonReentrant {
        require(daoProposals[daoAt][proposalAt].status == 10, "Proposal status error.");
        require(block.timestamp >= daoProposals[daoAt][proposalAt].uintParams[3] && block.timestamp <= daoProposals[daoAt][proposalAt].uintParams[4], "proposal not vote time.");
        require(!lp || daos[daoAt].lp != address(0), "Dao not allow lp");
        require(daoProposals[daoAt][proposalAt].mutilOption || options.length == 1, "Proposal not allow mutilOption");
        require(options.length <= daoProposals[daoAt][proposalAt].options.length);
        if (lp) {
            uint256 lpPrice = lpToTokenPrice(daos[daoAt].lp, daos[daoAt].token);
            uint256 totalAmount;
            for (uint8 i = 0; i < options.length; i++) {
                daoProposals[daoAt][proposalAt].votes[options[i]] += (amounts[i] * lpPrice) / 1e18;
                daoProposals[daoAt][proposalAt].totalVote += (amounts[i] * lpPrice) / 1e18;
                totalAmount += amounts[i];
            }
            IERC20(daos[daoAt].lp).safeTransferFrom(msg.sender, address(this), totalAmount);
            proposalVotes[daoAt][proposalAt].push(Vote({voter: msg.sender, lpAmount: totalAmount, tokenAmount: (totalAmount * lpPrice) / 1e18, options: options, amounts: amounts, status: true}));
        } else {
            uint256 totalAmount;
            for (uint8 i = 0; i < options.length; i++) {
                daoProposals[daoAt][proposalAt].votes[options[i]] += amounts[i];
                daoProposals[daoAt][proposalAt].totalVote += amounts[i];
                totalAmount += amounts[i];
            }
            IERC20(daos[daoAt].token).safeTransferFrom(msg.sender, address(this), totalAmount);
            proposalVotes[daoAt][proposalAt].push(Vote({voter: msg.sender, lpAmount: 0, tokenAmount: totalAmount, options: options, amounts: amounts, status: true}));
        }
        userVoteRecord[msg.sender].add(voteRecordConcat(daoAt, proposalAt, uint16(proposalVotes[daoAt][proposalAt].length - 1)));
        emit LogUserVote(msg.sender, daoAt, proposalAt);
    }

    function voteFinsh(uint16 daoAt, uint16 proposalAt) external {
        require(daoProposals[daoAt][proposalAt].status == 20, "Proposal not end.");
        uint256 totalLp = 0;
        uint256 totalToken = 0;
        uint256 totalReward = 0;
        for (uint16 i = 0; i < proposalVotes[daoAt][proposalAt].length; i++) {
            if (proposalVotes[daoAt][proposalAt][i].voter == msg.sender && proposalVotes[daoAt][proposalAt][i].status) {
                proposalVotes[daoAt][proposalAt][i].status = false;
                if (proposalVotes[daoAt][proposalAt][i].lpAmount == 0) {
                    totalToken += proposalVotes[daoAt][proposalAt][i].tokenAmount;
                }
                totalLp += proposalVotes[daoAt][proposalAt][i].lpAmount;
                totalReward += proposalVotes[daoAt][proposalAt][i].tokenAmount;
            }
        }
        if (daoProposals[daoAt][proposalAt].uintParams[2] != 0) {
            totalReward = (totalReward * daoProposals[daoAt][proposalAt].uintParams[2]) / daoProposals[daoAt][proposalAt].totalVote;
            IERC20(daos[daoAt].token).safeTransfer(msg.sender, totalReward);
        }
        if (totalLp > 0) {
            IERC20(daos[daoAt].lp).safeTransfer(msg.sender, totalLp);
        }
        if (totalToken > 0) {
            IERC20(daos[daoAt].token).safeTransfer(msg.sender, totalToken);
        }
        emit LogVoteFinish(msg.sender, daoAt, proposalAt);
    }

    function voteRecord(
        uint16 daoAt,
        uint16 proposalAt,
        address addr,
        uint16 count
    ) external view returns (Vote[] memory) {
        Vote[] memory votes = proposalVotes[daoAt][proposalAt];
        Vote[] memory voteRecords = new Vote[](count);
        uint16 curser = 0;
        for (uint16 i = 0; i < votes.length; i++) {
            if (addr == votes[i].voter) {
                voteRecords[curser] = votes[i];
                curser++;
            }
        }
        return voteRecords;
    }

    function voteRecordList(
        uint16 daoAt,
        uint16 proposalAt,
        uint16 offset,
        uint16 count
    ) external view returns (Vote[] memory) {
        Vote[] memory voteRecords = new Vote[](count);
        uint256 length = proposalVotes[daoAt][proposalAt].length;
        if (length > count + offset) {
            length = count + offset;
        }
        for (uint16 i = offset; i < length; i++) {
            voteRecords[i - offset] = proposalVotes[daoAt][proposalAt][i];
        }
        return voteRecords;
    }

    function userCouncli(uint16 daoAt, address addr) public view returns (bool) {
        uint16 councliAt_ = councliAt(daoAt, addr);
        if (councliAt_ == noneExist) {
            return false;
        }
        if (daoCounclis[daoAt][councliAt_].status) {
            return true;
        } else {
            return false;
        }
    }

    function userVoteRecordQuery(address addr) external view returns (uint256[] memory) {
        return userVoteRecord[addr].values();
    }

    function voteRecordConcat(
        uint16 daoAt,
        uint16 proposalAt,
        uint16 voteAt
    ) public pure returns (uint256) {
        return uint256(daoAt) * 2**32 + uint256(proposalAt) * 2**16 + voteAt;
    }

    function voteRecordResolve(uint256 concat)
        external
        pure
        returns (
            uint16 daoAt,
            uint16 proposalAt,
            uint16 voteAt
        )
    {
        voteAt = uint16(concat);
        proposalAt = uint16(concat / (2**16));
        daoAt = uint16(concat / (2**32));
    }
}
