use starknet::{ContractAddress};
use boot_track::interfaces::iboot_track::{IBootTrackDispatcher, IBootTrackDispatcherTrait};

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address, stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp};

fn deploy_contract(name: ByteArray, owner: ContractAddress) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let mut constructor_calldata = ArrayTrait::new();
    constructor_calldata.append(owner.into());
    let (contract_address, _) = contract.deploy(@constructor_calldata).unwrap();
    contract_address
}

#[test]
fn test_constructor() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();  //Compiler recommends using the TryInto trait rather the contract_address_const

    // Deploy contract with owner
    let contract_address = deploy_contract("BootTrack", owner);
    let dispatcher = IBootTrackDispatcher { contract_address };

    // Test 1: Verify that the owner can create bootcamp which proves that the owner was correctly set
    start_cheat_caller_address(contract_address, owner);

    let first_bootcamp_id = dispatcher.create_bootcamp(
        "Test Bootcamp",
        3_u32,      //number_of_attendees
        8_u8,      // total_weeks
        2_u8,      // sessions_per_week  
        10_u16    // assignment_max_score
    );

    stop_cheat_caller_address(contract_address);

    // Test 2: Verify that first bootcamp ID is 1 to acertain that the initial value was correctly set by the constructor
    assert(first_bootcamp_id == 1, 'First bootcamp ID should be 1');

    // Test 3: Verify bootcamp was created with the correct data passed into it
    let (name, total_weeks, sessions_per_week, max_score, num_of_attendees, is_active) = 
        dispatcher.get_bootcamp_info(first_bootcamp_id);

    assert(name == "Test Bootcamp", 'Wrong bootcamp name');
    assert_eq!(total_weeks, 8, "Wrong total weeks");
    assert_eq!(sessions_per_week, 2, "Wrong sessions per week");
    assert_eq!(max_score, 10, "Wrong max score");
    assert_eq!(num_of_attendees, 3, "Wrong number of attendees");
    assert(is_active, 'Bootcamp should be active');

    // Test 4: Verify second bootcamp gets ID 2 (proves counter increments correctly)
    start_cheat_caller_address(contract_address, owner);

    let second_bootcamp_id = dispatcher.create_bootcamp(
        "Second Bootcamp",
        3_u32,
        4_u8,
        3_u8,
        10_u16
    );

    stop_cheat_caller_address(contract_address);

    // Test 5: Verify bootcamp ID is now 2
    assert_eq!(second_bootcamp_id, 2, "Second bootcamp ID should be 2");
}

// This just tests the assertion used in the create_bootcamp function. Therefore I'm expecting it to panic if the caller isn't the owner.
#[test]
#[should_panic(expected: "Only owner can create bootcamp")]
fn test_constructor_non_owner() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let non_owner: ContractAddress = 0x456_felt252.try_into().unwrap();

    // Deploy contract with owner
    let contract_address = deploy_contract("BootTrack", owner);
    let dispatcher = IBootTrackDispatcher { contract_address };

    // Test 1: Verify non-owner cannot create a bootcamp
    start_cheat_caller_address(contract_address, non_owner);

    let _bootcamp_id = dispatcher.create_bootcamp(
        "Unauthorized Bootcamp",
        3_u32,
        8_u8,
        2_u8,
        10_u16
    );

    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_create_bootcamp() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);
    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);

    let bootcamp_id = dispatcher.create_bootcamp(
        "Cairo Bootcamp IV",
        3_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    stop_cheat_caller_address(contract_address);

    assert_eq!(bootcamp_id, 1, "First bootcamp should have ID 1");

    let (name, total_weeks, sessions_per_week, max_score, num_of_attendees, is_active) = 
        dispatcher.get_bootcamp_info(bootcamp_id);

    assert_eq!(name, "Cairo Bootcamp IV", "Bootcamp name does not match");
    assert_eq!(total_weeks, 10, "Total weeks do not match");
    assert_eq!(sessions_per_week, 2, "Sessions per week do not match");
    assert_eq!(max_score, 10, "Max score does not match");
    assert_eq!(is_active, true, "Bootcamp should be active");
    assert_eq!(num_of_attendees, 3, "Number of attendees does not match");
}

#[test]
fn test_register_mutliple_attendees() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    
    let attendee1: ContractAddress = 0x456_felt252.try_into().unwrap();
    let attendee2: ContractAddress = 0x789_felt252.try_into().unwrap();
    let attendee3: ContractAddress = 0xABC_felt252.try_into().unwrap();

    let contract_address = deploy_contract("BootTrack", owner);
    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);

    let bootcamp_id = dispatcher.create_bootcamp(
        "Cairo Bootcamp IV",
        3_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    attendees.append(attendee1);
    attendees.append(attendee2);
    attendees.append(attendee3);

    let result = dispatcher.register_attendees(bootcamp_id, attendees);
    stop_cheat_caller_address(contract_address);

    assert_eq!(result, true, "Registeration successful");

    let (_, _, _, _, num_of_attendees, _) = dispatcher.get_bootcamp_info(bootcamp_id);

    assert_eq!(num_of_attendees, 3, "Number of attendees incorrect");
}

#[test]
fn test_resgister_single_attendee() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();

    let attendee: ContractAddress = 0x456_felt252.try_into().unwrap();

    let contract_address = deploy_contract("BootTrack", owner);
    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);

    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        3_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    attendees.append(attendee);

    let result = dispatcher.register_attendees(bootcamp_id, attendees);

    stop_cheat_caller_address(contract_address);

    assert_eq!(result, true, "Registeration failed");
}

#[test]
fn test_open_attendance() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);

    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        3_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    // Open attendance for 1 hour for the week 1, session 1 
    let result = dispatcher.open_attendance(bootcamp_id, 1, 1, 60);

    stop_cheat_caller_address(contract_address);

    assert_eq!(result, true, "Attendance opening failed");

    let is_open = dispatcher.is_attendance_open(bootcamp_id, 1, 1);
    assert_eq!(is_open, true, "Attendance should be open for week 1 session 1");
}

#[test]
#[should_panic(expected: 'Only organizer can open')]
fn test_open_attendance_non_organizer_should_fail() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let non_organizer: ContractAddress = 0x456_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);

    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        3_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, non_organizer);
    dispatcher.open_attendance(bootcamp_id, 1, 1, 60);
    stop_cheat_caller_address(contract_address);
}


#[test]
#[should_panic(expect: 'Invalid week')]
fn test_open_attendance_invalid_week() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);

    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        3_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    dispatcher.open_attendance(bootcamp_id, 11_u8, 1_u8, 60_u32);

    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expect: 'Invalid session')]
fn test_open_attendance_invalid_session() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);

    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        3_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    dispatcher.open_attendance(bootcamp_id, 11_u8, 3_u8, 60_u32);
}

#[test]
fn test_mark_attendance_success() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let attendee: ContractAddress = 0x456_felt252.try_into().unwrap();

    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);

    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    attendees.append(attendee);
    dispatcher.register_attendees(bootcamp_id, attendees);

    // Open attendance by the organizer
    dispatcher.open_attendance(bootcamp_id, 1, 1, 60);
    stop_cheat_caller_address(contract_address);

    // Mark the attendance as an attendee
    start_cheat_caller_address(contract_address, attendee);
    let result = dispatcher.mark_attendance(bootcamp_id, 1, 1);
    stop_cheat_caller_address(contract_address);

    assert_eq!(result, true, "Result must return true");

  let (attendance_count, total_assignment_score, attendance_rate, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
  assert_eq!(attendance_count, 1, "Attendance count must be 1");
  assert_eq!(total_assignment_score, 0, "Total Assignment score should be 0");
  assert_eq!(attendance_rate, 5, "Attendance rate should be 5");
}

#[test]
fn test_mark_attendance_multiple_attendees() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);
    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        3_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    let attendee1: ContractAddress = 0x456_felt252.try_into().unwrap();
    let attendee2: ContractAddress = 0x678_felt252.try_into().unwrap();
    let attendee3: ContractAddress = 0x890_felt252.try_into().unwrap();

    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    attendees.append(attendee1);
    attendees.append(attendee2);
    attendees.append(attendee3);

    dispatcher.register_attendees(bootcamp_id, attendees);
    dispatcher.open_attendance(bootcamp_id, 2, 1, 60);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, attendee1);
    let result1 = dispatcher.mark_attendance(bootcamp_id, 2, 1);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, attendee2);
    let result2 = dispatcher.mark_attendance(bootcamp_id, 2, 1);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, attendee3);
    let result3 = dispatcher.mark_attendance(bootcamp_id, 2, 1);
    stop_cheat_caller_address(contract_address);

    assert_eq!(result1, true, "Attendance 1 must be true");
    assert_eq!(result2, true, "Attendance 2 must be true");
    assert_eq!(result3, true, "Attendance 3 must be true");

    let (attendance_count1, _, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee1);
    let (attendance_count2, _, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee2);
    let (attendance_count3, _, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee3);

    assert_eq!(attendance_count1, 1, "Attendance 1 should be 1");
    assert_eq!(attendance_count2, 1, "Attendance 1 should be 2");
    assert_eq!(attendance_count3, 1, "Attendance 1 should be 3");

}

#[test]
#[should_panic(expect: ("Not registered"))]
fn test_mark_attendance_unregistered_attendee() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let unregistered_attendee: ContractAddress = 0x456_felt252.try_into().unwrap();

    let contract_address = deploy_contract("BootTrack", owner);
    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);

    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );
    
    dispatcher.open_attendance(bootcamp_id, 2_u8, 2_u8, 60);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, unregistered_attendee);
    dispatcher.mark_attendance(bootcamp_id, 2_u8, 2_u8);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expect: ("Attendance not open"))]
fn test_mark_attendance_session_not_open() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);

    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    let attendee: ContractAddress = 0x456_felt252.try_into().unwrap();
    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    attendees.append(attendee);

    dispatcher.register_attendees(bootcamp_id, attendees);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, attendee);
    dispatcher.mark_attendance(bootcamp_id, 2_u8, 1_u8);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expect: ("Attendance timeframe elapsed"))]
fn test_mark_attendance_time_end() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);
    let dispatcher = IBootTrackDispatcher { contract_address };

    let start_time = 1000000_u64;
    start_cheat_block_timestamp(contract_address, start_time);

    start_cheat_caller_address(contract_address, owner);

    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
    1_u32,      //num_of_attendees
    10_u8,      // total_weeks
    2_u8,      // sessions_per_week
    10_u16    // assignment_max_score
    );

    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    let attendee: ContractAddress = 0x456_felt252.try_into().unwrap();
    attendees.append(attendee);
    dispatcher.register_attendees(bootcamp_id, attendees);

    // Open the attendance for 1hour
    dispatcher.open_attendance(bootcamp_id, 2_u8, 1_u8, 60_u32);
    stop_cheat_caller_address(contract_address);

    // Move the time forward
    start_cheat_block_timestamp(contract_address, start_time + (65 * 60));

    start_cheat_caller_address(contract_address, attendee);
    dispatcher.mark_attendance(bootcamp_id, 2_u8, 1_u8);
    stop_cheat_caller_address(contract_address);

    stop_cheat_block_timestamp(contract_address);
}

#[test]
#[should_panic(expect: ("Already marked attendance"))]
fn test_mark_attendance_already_marked() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );
    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    let attendee: ContractAddress = 0x456_felt252.try_into().unwrap();
    attendees.append(attendee);

    dispatcher.register_attendees(bootcamp_id, attendees);

    dispatcher.open_attendance(bootcamp_id, 2, 2, 60);

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, attendee);
    let result = dispatcher.mark_attendance(bootcamp_id, 2, 2);
    assert_eq!(result, true, "First attendance should succeed");

    dispatcher.mark_attendance(bootcamp_id, 2, 2);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_close_attendance_success() {
    let owner:ContractAddress = 0x123_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );
   let result = dispatcher.open_attendance(bootcamp_id, 2_u8, 1_u8, 60_u32);
   assert_eq!(result, true, "Attendance should be open");

   let is_open_before = dispatcher.is_attendance_open(bootcamp_id, 2_u8, 1_u8);
   assert_eq!(is_open_before, true, "Attendance should already be open");

   let close_result = dispatcher.close_attendance(bootcamp_id, 2_u8, 1_u8);
   stop_cheat_caller_address(contract_address);

   assert_eq!(close_result, true, "Attendance should be close");

   let is_open_after = dispatcher.is_attendance_open(bootcamp_id, 2_u8, 1_u8);
   assert_eq!(is_open_after, false, "Attendance should already be closed");
}

#[test]
fn test_close_multiple_attendance() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);
    
    let dispatcher = IBootTrackDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );
    let open_session1 = dispatcher.open_attendance(bootcamp_id, 1_u8, 0_u8, 60);
    let open_session2 = dispatcher.open_attendance(bootcamp_id, 1_u8, 1_u8, 60);
    let open_session3 = dispatcher.open_attendance(bootcamp_id, 2_u8, 0_u8, 60);

    assert_eq!(open_session1, true, "Week 1 session 1 attendance should be open");
    assert_eq!(open_session2, true, "Week 1 session 2 attendance should be open");
    assert_eq!(open_session3, true, "Week 2 session 1 attendance should be open");

    let is_open_before1 = dispatcher.is_attendance_open(bootcamp_id, 1_u8, 0_u8); 
    let is_open_before2 = dispatcher.is_attendance_open(bootcamp_id, 1_u8, 1_u8); 
    let is_open_before3 = dispatcher.is_attendance_open(bootcamp_id, 2_u8, 0_u8);

    assert_eq!(is_open_before1, true, "Week 1 session 1 attendance is opened before");
    assert_eq!(is_open_before2, true, "Week 1 session 2 attendance is opened before");
    assert_eq!(is_open_before3, true, "Week 2 session 1 attendance is opened before");

    let close_session1 = dispatcher.close_attendance(bootcamp_id, 1_u8, 0_u8);
    let close_session2 = dispatcher.close_attendance(bootcamp_id, 1_u8, 1_u8);
    let close_session3 = dispatcher.close_attendance(bootcamp_id, 2_u8, 0_u8);
    stop_cheat_caller_address(contract_address);

    assert_eq!(close_session1, true, "Week 1 session 1 attendance should be closed");
    assert_eq!(close_session2, true, "Week 1 session 2 attendance should be closed");
    assert_eq!(close_session3, true, "Week 2 session 1 attendance should be closed");

    let is_open_after1 = dispatcher.is_attendance_open(bootcamp_id, 1_u8, 0_u8);
    let is_open_after2 = dispatcher.is_attendance_open(bootcamp_id, 1_u8, 1_u8);
    let is_open_after3 = dispatcher.is_attendance_open(bootcamp_id, 2_u8, 0_u8);

    assert_eq!(is_open_after1, false, "Week 1 session 1 attendance must be close");
    assert_eq!(is_open_after2, false, "Week 1 session 2 attendance must be close");
    assert_eq!(is_open_after3, false, "Week 2 session 1 attendance must be close");
}

#[test]
#[should_panic(expect: ("Only the organizer can close attendance"))]
fn test_close_attendance_by_non_organizer() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let non_owner: ContractAddress = 0x456_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );
    dispatcher.open_attendance(bootcamp_id, 1_u8, 0_u8, 60);
    let is_open = dispatcher.is_attendance_open(bootcamp_id, 1_u8, 0_u8);
    stop_cheat_caller_address(contract_address);

    assert_eq!(is_open, true, "Attendance should be open");

    start_cheat_caller_address(contract_address, non_owner);
    dispatcher.close_attendance(bootcamp_id, 1_u8, 0_u8);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expect: ("Attendance has already been closed"))]
fn test_close_attendance_already_closed() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };
    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );
    dispatcher.open_attendance(bootcamp_id, 1_u8, 0_u8, 60);
    dispatcher.close_attendance(bootcamp_id, 1_u8, 0_u8);
    dispatcher.close_attendance(bootcamp_id, 1_u8, 0_8);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_grade_assignment_single_attendee() {
    let owner:ContractAddress = 0x123_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    let attendee: ContractAddress = 0x345_felt252.try_into().unwrap();
    attendees.append(attendee);

    dispatcher.register_attendees(bootcamp_id, attendees);

    let tutor = 0x567_felt252.try_into().unwrap();

    dispatcher.add_tutor(bootcamp_id, tutor);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, tutor);
    let result = dispatcher.grade_assignment(bootcamp_id, 1_u8, attendee, 8_u16);
    stop_cheat_caller_address(contract_address);

    assert_eq!(result, true, "Assignment should be graded");

    let (_, total_assignment_score, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);

    assert_eq!(total_assignment_score, 8, "Assignment score must be 8");
}

#[test]
fn test_grade_assignment_single_attendee_multiple() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    let attendee: ContractAddress = 0x345_felt252.try_into().unwrap();
    attendees.append(attendee);
    
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    dispatcher.register_attendees(bootcamp_id, attendees);

    let tutor: ContractAddress = 0x567_felt252.try_into().unwrap();
    dispatcher.add_tutor(bootcamp_id, tutor);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, tutor);
    let (_, initial_assignment_score, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(initial_assignment_score, 0, "Initial score should be zero");
    dispatcher.grade_assignment(bootcamp_id, 1_u8, attendee, 7_u16);
    let (_, current_assignment_score, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(current_assignment_score, 7);
    dispatcher.grade_assignment(bootcamp_id, 2_u8, attendee, 8_u16);

    let (_, total_assignment_score, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(total_assignment_score, 15, "Total score should be 15");
}

#[test]
#[should_panic(expect: ("Only the tutor or the organizer can grade assignment"))]
fn test_grade_assignment_non_tutor_or_organizer() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let tutor: ContractAddress = 0x345_felt252.try_into().unwrap();
    let non_organizer_or_tutor: ContractAddress = 0x567.try_into().unwrap();

    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    let attendee: ContractAddress = 0x789.try_into().unwrap();
    attendees.append(attendee);

    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    dispatcher.register_attendees(bootcamp_id, attendees);
    
    dispatcher.add_tutor(bootcamp_id, tutor);

    stop_cheat_caller_address(contract_address);
    let (_, initial_assignment_score, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(initial_assignment_score, 0, "Initial score should be zero");

    start_cheat_caller_address(contract_address, tutor);
    dispatcher.grade_assignment(bootcamp_id, 2_u8, attendee, 8_u16);
    stop_cheat_caller_address(contract_address);

    let (_, current_assignment_score, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(current_assignment_score, 8_u16);

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, non_organizer_or_tutor);
    dispatcher.grade_assignment(bootcamp_id, 2_u8, attendee, 8_u16); //Should panic
}

#[test]
#[should_panic(expect: ("Attendee is not registered"))]
fn test_grade_assignment_attendee_not_registered() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let tutor: ContractAddress = 0x345_felt252.try_into().unwrap();
    let attendee: ContractAddress = 0x567_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);

    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    dispatcher.add_tutor(bootcamp_id, tutor);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, tutor);
    dispatcher.grade_assignment(bootcamp_id, 1_u8, attendee, 8_u16); //should panic
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expect: ("Score exceeds the maximum allowed"))]
fn test_grade_assignment_score_exceeded_maximum() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let tutor: ContractAddress = 0x345_felt252.try_into().unwrap();

    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    let attendee: ContractAddress = 0x789.try_into().unwrap();
    attendees.append(attendee);

    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    dispatcher.register_attendees(bootcamp_id, attendees);
    
    dispatcher.add_tutor(bootcamp_id, tutor);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, tutor);
    dispatcher.grade_assignment(bootcamp_id, 2_u8, attendee, 21_u16); //expect to panic
    stop_cheat_caller_address(contract_address);
}

#[test]
#[should_panic(expect: ("Invalid week"))]
fn test_grade_assignment_invalid_week() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let tutor: ContractAddress = 0x345_felt252.try_into().unwrap();

    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    let attendee: ContractAddress = 0x789.try_into().unwrap();
    attendees.append(attendee);

    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    dispatcher.register_attendees(bootcamp_id, attendees);
    
    dispatcher.add_tutor(bootcamp_id, tutor);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, tutor);
    dispatcher.grade_assignment(bootcamp_id, 11_u8, attendee, 12_u16); //expect to panic
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_grade_assignment_regarde_score() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let tutor: ContractAddress = 0x345_felt252.try_into().unwrap();

    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    let attendee: ContractAddress = 0x789.try_into().unwrap();
    attendees.append(attendee);

    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    dispatcher.register_attendees(bootcamp_id, attendees);
    
    dispatcher.add_tutor(bootcamp_id, tutor);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, tutor);
    let (_, before_grade_score, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(before_grade_score, 0, "Score must be zero");
    dispatcher.grade_assignment(bootcamp_id, 2_u8, attendee, 6_u16);
    let (_, after_grade_score, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(after_grade_score, 6, "Score must be 6");
    dispatcher.grade_assignment(bootcamp_id, 2_u8, attendee, 8_u16);
    let (_, updated_grade_score, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(updated_grade_score, 8, "Score must be 6");
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_batch_grade_assignments_success() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let tutor: ContractAddress = 0x789_felt252.try_into().unwrap();

    let contract_address = deploy_contract("BootTrack", owner);
    let dispatcher = IBootTrackDispatcher { contract_address };

    let mut attendees: Array<ContractAddress> = ArrayTrait::new();

    let attendee1: ContractAddress = 0x345_felt252.try_into().unwrap();
    let attendee2: ContractAddress = 0x456_felt252.try_into().unwrap();
    let attendee3: ContractAddress = 0x567_felt252.try_into().unwrap();

    attendees.append(attendee1);
    attendees.append(attendee2);
    attendees.append(attendee3);

    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        3_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    dispatcher.register_attendees(bootcamp_id, attendees.clone());

    dispatcher.add_tutor(bootcamp_id, tutor);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, tutor);
    let mut batch_attendees: Array<ContractAddress> = ArrayTrait::new();
    batch_attendees.append(attendee1);
    batch_attendees.append(attendee2);
    batch_attendees.append(attendee3);

    let mut scores: Array<u16> = ArrayTrait::new();
    scores.append(8);
    scores.append(6);
    scores.append(10);

    let result = dispatcher.batch_grade_assignments(bootcamp_id, 2_u8, attendees, scores);
    stop_cheat_caller_address(contract_address);

    assert_eq!(result, true, "Result must be true");

    let (_, attendee1_score, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee1);
    let (_, attendee2_score, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee2);
    let (_, attendee3_score, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee3);

    assert_eq!(attendee1_score, 8, "Attendee 1 score must be 8");
    assert_eq!(attendee2_score, 6, "Attendee 1 score must be 6");
    assert_eq!(attendee3_score, 10, "Attendee 1 score must be 10");
}

#[test]
#[should_panic(expect: ("Arrays length mismatch"))]
fn test_batch_grade_assignment_attendee_score_mismatch() {
    let owner: ContractAddress = 0x123.try_into().unwrap();
    let tutor: ContractAddress = 0x789.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        2_u32,      //num_of_attendees
        10_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    let attendee1: ContractAddress = 0x345_felt252.try_into().unwrap();
    let attendee2: ContractAddress = 0x456_felt252.try_into().unwrap();
    
    attendees.append(attendee1);
    attendees.append(attendee2);

    dispatcher.register_attendees(bootcamp_id, attendees.clone());

    dispatcher.add_tutor(bootcamp_id, tutor);

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, tutor);
    let mut batch_attendees: Array<ContractAddress> = ArrayTrait::new();
    batch_attendees.append(attendee1);
    batch_attendees.append(attendee2);

    let mut scores: Array<u16> = ArrayTrait::new();
    scores.append(9);

    dispatcher.batch_grade_assignments(bootcamp_id, 2_u8, attendees, scores); //should panic
}

#[test]
fn test_process_graduation_no_graduation_status() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        8_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    let attendee: ContractAddress = 0x345_felt252.try_into().unwrap();
 
    attendees.append(attendee);

    dispatcher.register_attendees(bootcamp_id, attendees.clone());

    let (before_attendance_count, _, _, status_before) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(status_before, 0, "Graduation status must be false");
    assert_eq!(before_attendance_count, 0, "Attendance count must be zero");

    dispatcher.open_attendance(bootcamp_id, 1_u8, 0_u8, 30); //open for 30mins
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, attendee);
    dispatcher.mark_attendance(bootcamp_id, 1_u8, 0_u8);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, owner);
    dispatcher.open_attendance(bootcamp_id, 1_u8, 1_u8, 30);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, attendee);
    dispatcher.mark_attendance(bootcamp_id, 1_u8, 1_u8);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, owner);
    dispatcher.open_attendance(bootcamp_id, 2_u8, 0_u8, 30);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, attendee);
    dispatcher.mark_attendance(bootcamp_id, 2_u8, 0_u8);
    stop_cheat_caller_address(contract_address);

    let (attendance_count, _, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(attendance_count, 3, "Attendance count must be 3");

    start_cheat_caller_address(contract_address, owner);

    let tutor: ContractAddress = 0x678_felt252.try_into().unwrap();
    dispatcher.add_tutor(bootcamp_id, tutor);

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, tutor);

    let (_, total_assignment_score_before, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(total_assignment_score_before, 0, "Assignment score must be 0");

    dispatcher.grade_assignment(bootcamp_id, 1_u8, attendee, 10_u16);
    dispatcher.grade_assignment(bootcamp_id, 2_u8, attendee, 8_u16);
    dispatcher.grade_assignment(bootcamp_id, 3_u8, attendee, 10_u16);

    let (_, total_assignment_score_after, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(total_assignment_score_after, 28, "Total Assignment score must be 28");

    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, owner);
    dispatcher.process_graduation(bootcamp_id, attendee);
    let (_, _, _, status_after) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(status_after, 0, "Status after must be zero");
}

#[test]
fn test_process_graduation_attendee_status() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        4_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    let attendee: ContractAddress = 0x345_felt252.try_into().unwrap();
 
    attendees.append(attendee);

    dispatcher.register_attendees(bootcamp_id, attendees.clone());

    let (before_attendance_count, _, _, status_before) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(status_before, 0, "Graduation status must be false");
    assert_eq!(before_attendance_count, 0, "Attendance count must be zero");

    dispatcher.open_attendance(bootcamp_id, 1_u8, 0_u8, 30); //open for 30mins
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, attendee);
    dispatcher.mark_attendance(bootcamp_id, 1_u8, 0_u8);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, owner);
    dispatcher.open_attendance(bootcamp_id, 1_u8, 1_u8, 30);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, attendee);
    dispatcher.mark_attendance(bootcamp_id, 1_u8, 1_u8);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, owner);
    dispatcher.open_attendance(bootcamp_id, 2_u8, 0_u8, 30);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, attendee);
    dispatcher.mark_attendance(bootcamp_id, 2_u8, 0_u8);
    stop_cheat_caller_address(contract_address);

    let (after_attendance_count, _, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(after_attendance_count, 3, "Attendance count must be 3");

    start_cheat_caller_address(contract_address, owner);
    dispatcher.process_graduation(bootcamp_id, attendee);
    stop_cheat_caller_address(contract_address);
    let (_, _, _, status_after) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(status_after, 1, "Status after must be 1");
}

#[test]
fn test_process_graduation_normal_graduate_status() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let tutor: ContractAddress = 0x678_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        4_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    let attendee: ContractAddress = 0x345_felt252.try_into().unwrap();
 
    attendees.append(attendee);

    dispatcher.register_attendees(bootcamp_id, attendees.clone());

    let (before_attendance_count, _, _, status_before) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(status_before, 0, "Graduation status must be false");
    assert_eq!(before_attendance_count, 0, "Attendance count must be zero");

    dispatcher.open_attendance(bootcamp_id, 1_u8, 0_u8, 30); //open for 30mins
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, attendee);
    dispatcher.mark_attendance(bootcamp_id, 1_u8, 0_u8);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, owner);
    dispatcher.open_attendance(bootcamp_id, 1_u8, 1_u8, 30);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, attendee);
    dispatcher.mark_attendance(bootcamp_id, 1_u8, 1_u8);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, owner);
    dispatcher.open_attendance(bootcamp_id, 2_u8, 0_u8, 30);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, attendee);
    dispatcher.mark_attendance(bootcamp_id, 2_u8, 0_u8);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, owner);
    dispatcher.open_attendance(bootcamp_id, 2_u8, 1_u8, 30);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, attendee);
    dispatcher.mark_attendance(bootcamp_id, 2_u8, 1_u8);
    stop_cheat_caller_address(contract_address);

    let (after_attendance_count, _, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(after_attendance_count, 4, "Attendance count must be 4");

    start_cheat_caller_address(contract_address, owner);
    dispatcher.add_tutor(bootcamp_id, tutor);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, tutor);
    dispatcher.grade_assignment(bootcamp_id, 1_u8, attendee, 7);
    dispatcher.grade_assignment(bootcamp_id, 2_u8, attendee, 6);
    dispatcher.grade_assignment(bootcamp_id, 3_u8, attendee, 10);
    stop_cheat_caller_address(contract_address);

    let (_, total_assignment_score, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);

    assert_eq!(total_assignment_score, 23, "Total assignment must be 23");

    dispatcher.process_graduation(bootcamp_id, attendee);
    let (_, _, _, status_after) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(status_after, 2, "Status after must be 2");
}

#[test]
fn test_process_graduation_distinction_status() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let tutor: ContractAddress = 0x678_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        4_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    let attendee: ContractAddress = 0x345_felt252.try_into().unwrap();
 
    attendees.append(attendee);

    dispatcher.register_attendees(bootcamp_id, attendees.clone());

    let (before_attendance_count, _, _, status_before) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(status_before, 0, "Graduation status must be false");
    assert_eq!(before_attendance_count, 0, "Attendance count must be zero");

    dispatcher.open_attendance(bootcamp_id, 1_u8, 0_u8, 30); //open for 30mins
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, attendee);
    dispatcher.mark_attendance(bootcamp_id, 1_u8, 0_u8);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, owner);
    dispatcher.open_attendance(bootcamp_id, 1_u8, 1_u8, 30);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, attendee);
    dispatcher.mark_attendance(bootcamp_id, 1_u8, 1_u8);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, owner);
    dispatcher.open_attendance(bootcamp_id, 2_u8, 0_u8, 30);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, attendee);
    dispatcher.mark_attendance(bootcamp_id, 2_u8, 0_u8);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, owner);
    dispatcher.open_attendance(bootcamp_id, 2_u8, 1_u8, 30);
    stop_cheat_caller_address(contract_address);
    start_cheat_caller_address(contract_address, attendee);
    dispatcher.mark_attendance(bootcamp_id, 2_u8, 1_u8);
    stop_cheat_caller_address(contract_address);

    let (after_attendance_count, _, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(after_attendance_count, 4, "Attendance count must be 4");

    start_cheat_caller_address(contract_address, owner);
    dispatcher.add_tutor(bootcamp_id, tutor);
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, tutor);
    dispatcher.grade_assignment(bootcamp_id, 1_u8, attendee, 7);
    dispatcher.grade_assignment(bootcamp_id, 2_u8, attendee, 8);
    dispatcher.grade_assignment(bootcamp_id, 3_u8, attendee, 10);
    dispatcher.grade_assignment(bootcamp_id, 4_u8, attendee, 9);
    stop_cheat_caller_address(contract_address);

    let (_, total_assignment_score, _, _) = dispatcher.get_attendee_stats(bootcamp_id, attendee);

    assert_eq!(total_assignment_score, 34, "Total assignment must be 34");

    dispatcher.process_graduation(bootcamp_id, attendee);
    let (_, _, _, status_after) = dispatcher.get_attendee_stats(bootcamp_id, attendee);
    assert_eq!(status_after, 3, "Status after must be 3");
}

#[test]
#[should_panic(expect: ("Attendee is not registered"))]
fn test_process_graduation_attendee_not_registered() {
    let owner: ContractAddress = 0x123_felt252.try_into().unwrap();
    let contract_address = deploy_contract("BootTrack", owner);

    let dispatcher = IBootTrackDispatcher { contract_address };

    start_cheat_caller_address(contract_address, owner);
    let bootcamp_id = dispatcher.create_bootcamp("Cairo Bootcamp IV",
        1_u32,      //num_of_attendees
        4_u8,      // total_weeks
        2_u8,      // sessions_per_week
        10_u16    // assignment_max_score
    );

    let mut attendees: Array<ContractAddress> = ArrayTrait::new();
    let attendee1: ContractAddress = 0x345_felt252.try_into().unwrap();
    let attendee2: ContractAddress = 0x567_felt252.try_into().unwrap();

    attendees.append(attendee1);
    dispatcher.register_attendees(bootcamp_id, attendees);

    dispatcher.process_graduation(bootcamp_id, attendee1); //This should go through
    dispatcher.process_graduation(bootcamp_id, attendee2); //This should panic
}