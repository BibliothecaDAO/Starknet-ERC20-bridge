#[contract]

trait Mintable {
    fn mint(recipient: ContractAddress, amount: u256) -> bool;
}

trait Burnable {
    fn burn_away(owner: ContractAddress, amount: u256) -> bool;
}

mod LordsL2 {
    use array::ArrayTrait;
    use core::contract_address::ContractAddress;
    use core::integer::u256;

    const PROCESS_WITHDRAWAL = 1; // operation ID sent in the message payload to L1
    const U128_MAX: u128 = 0xffffffffffffffffffffffffffffffff_u128; // 2**128 - 1
    const ETH_ADDR_BOUND: felt = 1461501637330902918203684832716283019655932542976; // 2**160

    struct Storage {
        // L1 bridge contract address, the L1 counterpart to this contract
        l1_bridge: ContractAddress,
        // address of the $LORDS token contract on the L2
        l2_token: ContractAddress
    }

    #[constructor]
    fn constructor(l1_bridge: ContractAddress, l2_token: ContractAddress) {
        l1_bridge::write(l1_bridge);
        l2_token::write(l2_token);
    }

    #[l1_handler]
    fn handle_deposit(origin: ContractAddress, recipient: ContractAddress, amount_low: felt, amount_high: felt, _msg_sender: felt) {
        // note: `_msg_sender` is teh L1 msg.sender value, we don't use it

        assert(origin == l1_bridge::read(), 'invalid L1 message origin');

        let amount: u256 = u256 {
            low: amount_low.try_into().unwrap(),
            high: amount_high.try_into().unwrap())
        };

        // TODO: do contract call
        Mintable.mint(l2_token::read(), recipient, amount);
    }

    #[external]
    fn initiate_withdrawal(l1_recipient: felt, amount: u256) {
        assert_eth_address_range(l1_recipient);
        assert(l1_recipient != l1_bridge::read(), 'Recipient cannot be the bridge');

        // TODO: replace with correct syscall once available
        //let caller: felt = get_caller_address();
        let caller: felt = 0;

        // TODO: contract call
        Burnable.burn_away(l2_token::read(), caller, amount);

        // TODO: send message to L1
        let mut message: Array<felt> = ArrayTrait::new();
        message.append(PROCESS_WITHDRAWAL);
        message.append(l1_recipient);
        message.append(amount.low);
        message.append(amount.high);
        // send_message_to_l1(message);
    }

    #[view]
    fn get_l1_bridge() -> ContractAddress {
        l1_bridge::read()
    }

    #[view]
    fn get_token() -> ContractAddress {
        l2_token::read()
    }

    //
    // Internal
    //

    fn assert_eth_address_range(addr: felt) {
        assert(addr != 0, 'Ethereum address cannot be zero');
        assert(addr < ETH_ADDR_BOUND, 'Invalid Ethereum address');
    }
}

// TODO: test, how?
