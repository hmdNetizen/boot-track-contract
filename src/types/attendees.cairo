    use starknet::ContractAddress;

    // Data Structures
    #[derive(Drop, Serde, starknet::Store)]
    pub struct Bootcamp {
        pub name: ByteArray,
        pub organizer: ContractAddress,
        pub total_weeks: u8,
        pub sessions_per_week: u8,
        pub assignment_max_score: u16,
        pub is_active: bool,
        pub created_at: u64,
        pub num_of_attendees: usize
    }

    #[derive(Drop, Serde, Copy, starknet::Store)]
    pub struct AttendeeRecord {
        pub is_registered: bool,
        pub attendance_count: u8,
        pub total_assignment_score: u16,
        pub graduation_status: u8, // 0: None, 1: Attendee, 2: Graduate, 3: Distinction
    }

    #[derive(Drop, Serde, Copy, starknet::Store)]
    pub struct AttendanceSession {
        pub is_open: bool,
        pub opened_at: u64,
        pub duration_minutes: u32,
        pub total_attendees: u32,
    }

    #[derive(Drop, Serde, starknet::Store)]
    pub struct AssignmentGrade {
        pub score: u16,
        pub graded_by: ContractAddress,
        pub graded_at: u64,
        pub attendee: ContractAddress
    }