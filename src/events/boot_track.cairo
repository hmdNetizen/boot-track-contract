use starknet::ContractAddress;

#[derive(Drop, starknet::Event)]
pub struct BootcampCreated {
    pub bootcamp_id: u256,
    pub name: ByteArray,
    pub organizer: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct AttendeeRegistered {
    pub bootcamp_id: u256,
    pub attendee: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct TutorAdded {
    pub bootcamp_id: u256,
    pub tutor: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct AttendanceOpened {
    pub bootcamp_id: u256,
    pub week: u8,
    pub session_id: u8,
    pub duration_minutes: u32,
}

#[derive(Drop, starknet::Event)]
pub struct AttendanceMarked {
    pub bootcamp_id: u256,
    pub week: u8,
    pub session_id: u8,
    pub attendee: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct AttendanceClosed {
    pub bootcamp_id: u256,
    pub week: u8,
    pub session_id: u8,
    pub total_attendees: u32,
}

#[derive(Drop, starknet::Event)]
pub struct AssignmentGraded {
    pub bootcamp_id: u256,
    pub week: u8,
    pub attendee: ContractAddress,
    pub score: u16,
    pub graded_by: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct GraduationProcessed {
    pub bootcamp_id: u256,
    pub attendee: ContractAddress,
    pub graduation_status: u8,
}