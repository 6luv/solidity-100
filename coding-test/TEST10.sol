// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 < 0.9.0;

    /*
    은행에 관련된 어플리케이션을 만드세요.
    은행은 여러가지가 있고, 유저는 원하는 은행에 넣을 수 있다. 
    국세청은 은행들을 관리하고 있고, 세금을 징수할 수 있다. 
    세금은 간단하게 전체 보유자산의 1%를 징수한다. 세금을 자발적으로 납부하지 않으면 강제징수한다. 

    * 회원 가입 기능 - 사용자가 은행에서 회원가입하는 기능
    * 입금 기능 - 사용자가 자신이 원하는 은행에 가서 입금하는 기능
    * 출금 기능 - 사용자가 자신이 원하는 은행에 가서 출금하는 기능
    * 은행간 송금 기능 1 - 사용자의 A 은행에서 B 은행으로 자금 이동 (자금의 주인만 가능하게)
    * 은행간 송금 기능 2 - 사용자 1의 A 은행에서 사용자 2의 B 은행으로 자금 이동
    * 세금 징수 - 국세청은 주기적으로 사용자들의 자금을 파악하고 전체 보유량의 1%를 징수함. 세금 납부는 유저가 자율적으로 실행. (납부 후에는 납부 해야할 잔여 금액 0으로)
    -------------------------------------------------------------------------------------------------
    * 은행간 송금 기능 수수료 - 사용자 1의 A 은행에서 사용자 2의 B 은행으로 자금 이동할 때 A 은행은 그 대가로 사용자 1로부터 1 finney 만큼 수수료 징수.
    * 세금 강제 징수 - 국세청에게 사용자가 자발적으로 세금을 납부하지 않으면 강제 징수. 은행에 있는 사용자의 자금이 국세청으로 강제 이동
    */

contract TaxOffice {
    mapping(address => uint) public userTax;
    address[] public banks;

    function addBank(address _addr) public {
        banks.push(_addr);
    }

    function checkBank(address _addr) public view returns(bool) {
        for (uint i = 0; i < banks.length; i ++) {
            if (_addr == banks[i]) {
                return true;
            }
        }
        return false;
    }

    function collectTax() public {
        address[] memory users;
        for (uint i = 0; i < banks.length; i ++) {
            Bank bank = Bank(banks[i]);
            users = bank.getUsers();
            for (uint j = 0; j < users.length; j ++) {
                userTax[users[j]] += bank.getBalance(users[j]);
            }
        }

        for (uint i = 0; i < users.length; i ++) {
            userTax[users[i]] /= 100;
        }
    }

    function payTax() public payable {
        require(userTax[msg.sender] > 0);
        require(userTax[msg.sender] == msg.value);
        userTax[msg.sender] -= msg.value;
    }
}

contract Bank {
    TaxOffice taxOffice;

    constructor(address _taxOffice) {
        taxOffice = TaxOffice(_taxOffice);
        taxOffice.addBank(address(this));
    }

    mapping(address => uint) public balances;
    address[] public users;

    // * 회원 가입 기능 - 사용자가 은행에서 회원가입하는 기능
    function register() public {
        require(getUser(msg.sender) == address(0));
        balances[msg.sender] = 0;
        users.push(msg.sender);
    }

    // * 입금 기능 - 사용자가 자신이 원하는 은행에 가서 입금하는 기능
    function deposit() public payable {
        require(getUser(msg.sender) != address(0));
        balances[msg.sender] += msg.value;
    }

    // * 출금 기능 - 사용자가 자신이 원하는 은행에 가서 출금하는 기능
    function withdraw(uint _balance) public {
        require(getUser(msg.sender) != address(0));
        require(balances[msg.sender] >= _balance);
        balances[msg.sender] -= _balance;
        payable(msg.sender).transfer(_balance);
    }

    modifier checkTransfer(address _toBank, address _user, uint _balance) {
        require(balances[msg.sender] >= _balance);
        require(taxOffice.checkBank(_toBank));
        require(Bank(_toBank).getUser(_user) != address(0));
        _;
    }

    // * 은행간 송금 기능 1 - 사용자의 A 은행에서 B 은행으로 자금 이동 (자금의 주인만 가능하게)
    function transferBalance(address _toBank, uint _balance) public checkTransfer(_toBank, msg.sender, _balance) {
        balances[msg.sender] -= _balance;
        Bank(_toBank).receiveTransfer{value : _balance}(msg.sender);
    }

    // * 은행간 송금 기능 2 - 사용자 1의 A 은행에서 사용자 2의 B 은행으로 자금 이동
    // * 은행간 송금 기능 수수료 - 사용자 1의 A 은행에서 사용자 2의 B 은행으로 자금 이동할 때 A 은행은 그 대가로 사용자 1로부터 1 finney 만큼 수수료 징수.
    function transferUser(address _toBank, address _user, uint _balance) public payable checkTransfer(_toBank, _user, _balance) {
        require(msg.value >= 0.001 ether);
        balances[msg.sender] -= _balance;
        Bank(_toBank).receiveTransfer{value : _balance}(_user);
    }

    function receiveTransfer(address _user) public payable {
        balances[_user] += msg.value;
    }

    function getUsers() public view returns(address[] memory) {
        return users;
    }

    function getUser(address _addr) public view returns(address) {
        for (uint i = 0; i < users.length; i ++) {
            if (_addr == users[i]) {
                return _addr;
            }
        }
        return address(0);
    }

    function getBalance(address _user) public view returns(uint) {
        return balances[_user];
    }
}