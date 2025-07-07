use starknet::ContractAddress;
use crate::types::attendees::{ Bootcamp, AttendeeRecord, AssignmentGrade };

#[starknet::interface]
pub trait IBootTrack<TContractState> {
    // Setup Function Signatures
    fn create_bootcamp(ref self: TContractState, name: ByteArray, num_of_attendees: u32, total_weeks: u8, sessions_per_week: u8, assignment_max_score: u16) -> u256;
    fn register_attendees(ref self: TContractState, bootcamp_id: u256, attendees: Array<ContractAddress>) -> bool;
    fn add_tutor(ref self: TContractState, bootcamp_id: u256, tutor_address: ContractAddress) -> bool;

    // Attendance Function Signatures
    fn open_attendance(ref self: TContractState, bootcamp_id: u256, week: u8, session_id: u8, duration_minutes: u32) -> bool;
    fn mark_attendance(ref self: TContractState, bootcamp_id: u256, week: u8, session_id: u8) -> bool;
    fn close_attendance(ref self: TContractState, bootcamp_id: u256, week: u8, session_id: u8) -> bool;

    // Assignment Function Signatures
    fn grade_assignment(ref self: TContractState, bootcamp_id: u256, week: u8, attendee: ContractAddress, score: u16) -> bool;
    fn batch_grade_assignments(ref self: TContractState, bootcamp_id: u256, week: u8, attendees: Array<ContractAddress>, scores: Array<u16>) -> bool;

    // Graduation Function Signatures
    fn process_graduation(ref self: TContractState, bootcamp_id: u256, attendee: ContractAddress) -> u8;
    fn process_all_graduations(ref self: TContractState, bootcamp_id: u256, attendees: Array<ContractAddress>) -> bool;

    // Query Functions
    fn get_all_bootcamps(self: @TContractState) -> Array<(u256, Bootcamp)>;
    fn get_attendee_stats(self: @TContractState, bootcamp_id: u256, attendee: ContractAddress) -> (u8, u16, u8, u8);
    fn get_all_attendees(self: @TContractState, bootcamp_id: u256) -> Array<(ContractAddress, AttendeeRecord)>;
    fn get_bootcamp_info(self: @TContractState, bootcamp_id: u256) -> (ByteArray, u8, u8, u16, usize, bool, u64);
    fn is_attendance_open(self: @TContractState, bootcamp_id: u256,  week: u8, session_id: u8) -> bool;
    fn debug_bootcamp_data(self: @TContractState, bootcamp_id: u256) -> (ContractAddress, ContractAddress, ByteArray, bool);
    fn get_assignment_info(self: @TContractState, bootcamp_id: u256, week: u8, attendee: ContractAddress) -> AssignmentGrade;
}