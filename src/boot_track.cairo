use crate::interfaces::iboot_track::IBootTrack;

#[starknet::contract]
mod BootTrack {
use super::IBootTrack;
    use starknet::{
        ContractAddress, get_caller_address, get_block_timestamp,
        storage::{StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry}
    };
    use core::num::traits::Zero;
    use crate::types::attendees::{Bootcamp, AttendeeRecord, AttendanceSession, AssignmentGrade};
    use crate::events::boot_track::{AssignmentGraded, AttendanceClosed, AttendanceMarked, AttendanceOpened, AttendeeRegistered, BootcampCreated, TutorAdded, GraduationProcessed};


    #[storage]
    struct Storage {
        owner: ContractAddress,
        next_bootcamp_id: u256,
        
        // Bootcamp data
        bootcamps: Map<u256, Bootcamp>,
        
        bootcamp_attendee_by_index: Map<(u256, u32), ContractAddress>, // (bootcamp_id, index) -> attendee
        bootcamp_attendee_count: Map<u256, u32>,
        // Attendee records: bootcamp_id -> attendee -> record
        attendee_records: Map<(u256, ContractAddress), AttendeeRecord>,
        
        // Tutors: bootcamp_id -> tutor -> is_tutor
        tutors: Map<(u256, ContractAddress), bool>,
        
        // Attendance sessions: bootcamp_id -> week -> session_id -> session
        attendance_sessions: Map<(u256, u8, u8), AttendanceSession>,
        
        // Individual attendance: bootcamp_id -> week -> session_id -> attendee -> attended
        individual_attendance: Map<(u256, u8, u8, ContractAddress), bool>,
        
        // Assignment grades: bootcamp_id -> week -> attendee -> grade
        pub assignment_grades: Map<(u256, u8, ContractAddress), AssignmentGrade>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        BootcampCreated: BootcampCreated,
        AttendeeRegistered: AttendeeRegistered,
        TutorAdded: TutorAdded,
        AttendanceOpened: AttendanceOpened,
        AttendanceMarked: AttendanceMarked,
        AttendanceClosed: AttendanceClosed,
        AssignmentGraded: AssignmentGraded,
        GraduationProcessed: GraduationProcessed,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.next_bootcamp_id.write(1);
    }

    #[abi(embed_v0)]
    impl BootTrackImpl of IBootTrack<ContractState> {
        fn create_bootcamp(ref self: ContractState, name: ByteArray, num_of_attendees: u32, total_weeks: u8, sessions_per_week: u8, assignment_max_score: u16) -> u256 {
            let caller = get_caller_address();
            let bootcamp_id = self.next_bootcamp_id.read();
            
            let bootcamp = Bootcamp {
                name: name.clone(),
                organizer: caller,
                total_weeks,
                sessions_per_week,
                assignment_max_score,
                is_active: true,
                created_at: get_block_timestamp(),
                num_of_attendees
            };
            
            self.bootcamps.entry(bootcamp_id).write(bootcamp);
            self.next_bootcamp_id.write(bootcamp_id + 1);
            
            self.emit(BootcampCreated {
                bootcamp_id,
                name,
                organizer: caller,
            });
            
            bootcamp_id
        }

        fn register_attendees(ref self: ContractState, bootcamp_id: u256, mut attendees: Array<ContractAddress>) -> bool {
            let caller = get_caller_address();
            let mut bootcamp = self.bootcamps.entry(bootcamp_id).read();

            assert(bootcamp.organizer == caller, 'Only organizer can register');
            assert(bootcamp.is_active, 'Bootcamp not active');
            assert(attendees.len() != 0, 'Attendees data cannot be empty');

            let mut current_count = self.bootcamp_attendee_count.entry(bootcamp_id).read();

            while !attendees.is_empty() {
                let attendee = attendees.pop_front().unwrap();
                let record = AttendeeRecord {
                    is_registered: true,
                    attendance_count: 0,
                    total_assignment_score: 0,
                    graduation_status: 0,
                };
                
                self.attendee_records.entry((bootcamp_id, attendee)).write(record);

                // Add attendee to indexed storage
                self.bootcamp_attendee_by_index.entry((bootcamp_id, current_count)).write(attendee);
                current_count += 1;
                
                self.emit(AttendeeRegistered {
                    bootcamp_id,
                    attendee,
                });
            };

            // Update the count
            self.bootcamp_attendee_count.entry(bootcamp_id).write(current_count);
            
            true
        }
        fn add_tutor(ref self: ContractState, bootcamp_id: u256, tutor_address: ContractAddress) -> bool {
            let caller = get_caller_address();
            let bootcamp = self.bootcamps.entry(bootcamp_id).read();
            
            assert(bootcamp.organizer == caller, 'Only organizer can add tutors');
            
            self.tutors.entry((bootcamp_id, tutor_address)).write(true);
            
            self.emit(TutorAdded {
                bootcamp_id,
                tutor: tutor_address,
            });
            
            true
        }
        fn open_attendance(ref self: ContractState, bootcamp_id: u256, week: u8, session_id: u8, duration_minutes: u32) -> bool {
            let caller = get_caller_address();
            let bootcamp = self.bootcamps.entry(bootcamp_id).read();

            assert(bootcamp.organizer == caller, 'Only organizer can open');
            assert(week <= bootcamp.total_weeks, 'Invalid week');
            assert(session_id < bootcamp.sessions_per_week, 'Invalid session');

            let session = AttendanceSession {
                is_open: true,
                opened_at: get_block_timestamp(),
                duration_minutes,
                total_attendees: 0,
            };

            self.attendance_sessions.entry((bootcamp_id, week, session_id)).write(session);

            self.emit(AttendanceOpened {
                bootcamp_id,
                week,
                session_id,
                duration_minutes,
            });
            
            true
        }

        fn mark_attendance(ref self: ContractState, bootcamp_id: u256, week: u8, session_id: u8) -> bool {
            let caller = get_caller_address();
            let mut session = self.attendance_sessions.entry((bootcamp_id, week, session_id)).read();
            let attendee_record = self.attendee_records.entry((bootcamp_id, caller)).read();

            assert(attendee_record.is_registered, 'Not registered');
            assert(session.is_open, 'Attendance not open');

            // Check if attendance window is still valid
            let current_time = get_block_timestamp();
            let end_time = session.opened_at + (session.duration_minutes.into() * 60);
            assert(current_time <= end_time, 'Attendance timeframe elapsed');

            // Check if already marked
            let already_attended = self.individual_attendance.entry((bootcamp_id, week, session_id, caller)).read();
            assert(!already_attended, 'Already marked attendance');

            // Mark attendance
            self.individual_attendance.entry((bootcamp_id, week, session_id, caller)).write(true);

            // Update attendee record
            let mut updated_record = attendee_record;
            updated_record.attendance_count += 1;
            self.attendee_records.entry((bootcamp_id, caller)).write(updated_record);

            // Update session count
            session.total_attendees += 1;
            self.attendance_sessions.entry((bootcamp_id, week, session_id)).write(session);

            self.emit(AttendanceMarked {
                bootcamp_id,
                week,
                session_id,
                attendee: caller,
            });
            
            true
        }

        fn close_attendance(ref self: ContractState, bootcamp_id: u256, week: u8, session_id: u8) -> bool {
            let caller = get_caller_address();
            let bootcamps = self.bootcamps.entry(bootcamp_id).read();
            let mut session = self.attendance_sessions.entry((bootcamp_id, week, session_id)).read();

            assert(caller == bootcamps.organizer, 'Only the organizer can close');
            assert(session.is_open, 'Attendance already closed');

            session.is_open = false;
            self.attendance_sessions.entry((bootcamp_id, week, session_id)).write(session);

            self.emit(AttendanceClosed {
                bootcamp_id,
                week,
                session_id,
                total_attendees: session.total_attendees,
            });
            
            true
        }

        fn grade_assignment(ref self: ContractState, bootcamp_id: u256, week: u8, attendee: ContractAddress, score: u16) -> bool {
            let caller = get_caller_address();
            let bootcamp = self.bootcamps.entry(bootcamp_id).read();
            let is_tutor = self.tutors.entry((bootcamp_id, caller)).read();
            let attendee_record = self.attendee_records.entry((bootcamp_id, attendee)).read();

            assert(is_tutor || bootcamp.organizer == caller, 'Only tutor or organizer allowed');
            assert(attendee_record.is_registered, 'Attendee is not registered');
            assert(score <= bootcamp.assignment_max_score, 'Score exceeds the maximum');
            assert(week <= bootcamp.total_weeks, 'Invalid week');

            // Check if attendee has already been graded
            let existing_grade = self.assignment_grades.entry((bootcamp_id, week, attendee)).read();

            let grade = AssignmentGrade {
                score,
                graded_by: caller,
                graded_at: get_block_timestamp(),
                attendee
            };

            // Store the new grade
            self.assignment_grades.entry((bootcamp_id, week, attendee)).write(grade);

            // Update attendee's total score (remove old score, add new score)
            let mut updated_record = attendee_record;
            let old_score = existing_grade.score;
            updated_record.total_assignment_score = updated_record.total_assignment_score - old_score + score;

            self.attendee_records.entry((bootcamp_id, attendee)).write(updated_record);

            self.emit(AssignmentGraded {
                bootcamp_id,
                week,
                attendee,
                score,
                graded_by: caller,
            });
            
            true
        }

        fn batch_grade_assignments(ref self: ContractState, bootcamp_id: u256, week: u8, mut attendees: Array<ContractAddress>, mut scores: Array<u16>) -> bool {
            assert(attendees.len() == scores.len(), 'Arrays length mismatch');

            while !attendees.is_empty() {
                let attendee = attendees.pop_front().unwrap();
                let score = scores.pop_front().unwrap();

                self.grade_assignment(bootcamp_id, week, attendee, score);
            }

            true
        }

        fn process_graduation(ref self: ContractState, bootcamp_id: u256, attendee: ContractAddress) -> u8 {
            let bootcamp = self.bootcamps.entry(bootcamp_id).read();
            let mut attendee_record = self.attendee_records.entry((bootcamp_id, attendee)).read();

            assert(attendee_record.is_registered, 'Attendee is not registered');

            // Calculate total possible sessions
            let total_sessions = bootcamp.total_weeks * bootcamp.sessions_per_week;

            // Calculate attendance percentage
            // let attendance_percentage: u8 = (attendee_record.attendance_count.into() * 100) / total_sessions.into();
            let attendance_percentage: u8 = ((attendee_record.attendance_count.into() * 100_u32) / total_sessions.into()).try_into().unwrap();

            // Calculate max possible score
            let max_possible_score: u16 = bootcamp.total_weeks.into() * bootcamp.assignment_max_score.into();

            // Calculate score percentage
            let score_percentage = (attendee_record.total_assignment_score.into() * 100) / max_possible_score;

            // Use percentage-based thresholds
            let graduation_status = if attendance_percentage < 25 {
                0 // None
            } else if attendance_percentage >= 50 && score_percentage >= 80 { // 70% of max score
                3 // Distinction
            } else if attendance_percentage >= 50 && score_percentage >= 50 { // 50% of max score
                2 // Graduate
            } else {
                1 // Attendee
            };

            attendee_record.graduation_status = graduation_status;
            self.attendee_records.entry((bootcamp_id, attendee)).write(attendee_record);

            self.emit(GraduationProcessed {
                bootcamp_id,
                attendee,
                graduation_status,
            });
            
            graduation_status
        }

        fn process_all_graduations(ref self: ContractState, bootcamp_id: u256, mut attendees: Array<ContractAddress>) -> bool {
            let caller = get_caller_address();
            let bootcamp = self.bootcamps.entry(bootcamp_id).read();

            assert(bootcamp.organizer == caller, 'Only organizer can process this');

            //Batch process the attendees
            while !attendees.is_empty() {
                let attendee = attendees.pop_front().unwrap();
                self.process_graduation(bootcamp_id, attendee);
            }

            true

        }

        fn get_attendee_stats(self: @ContractState, bootcamp_id: u256, attendee: ContractAddress) -> (u8, u16, u8, u8) {
            let record = self.attendee_records.entry((bootcamp_id, attendee)).read();
            let bootcamp = self.bootcamps.entry(bootcamp_id).read();

            let total_sessions = bootcamp.total_weeks * bootcamp.sessions_per_week;
            let attendance_rate = if total_sessions > 0 {
                ((record.attendance_count.into() * 100_u32) / total_sessions.into()).try_into().unwrap()
            } else {
                0
            };

            (
                record.attendance_count,
                record.total_assignment_score,
                attendance_rate,
                record.graduation_status
            )
        }

        fn get_all_bootcamps(self: @ContractState) -> Array<(u256, Bootcamp)> {
            //     let caller = get_caller_address();

            let mut bootcamps_array = ArrayTrait::new();
            let total_bootcamps = self.next_bootcamp_id.read();
        
            let mut i: u256 = 1;

            while i < total_bootcamps {
                let bootcamp = self.bootcamps.entry(i).read();
                
                if bootcamp.name.len() > 0 {
                    bootcamps_array.append((i, bootcamp));
                }
                
                i += 1;
            }
            
            bootcamps_array
        }

        fn get_bootcamp_info(self: @ContractState, bootcamp_id: u256) -> (ByteArray, u8, u8, u16, usize, bool, u64) {
            let bootcamp = self.bootcamps.entry(bootcamp_id).read();
            (
                bootcamp.name,
                bootcamp.total_weeks,
                bootcamp.sessions_per_week,
                bootcamp.assignment_max_score,
                bootcamp.num_of_attendees,
                bootcamp.is_active,
                bootcamp.created_at
            )
        }

        fn is_attendance_open(self: @ContractState, bootcamp_id: u256,  week: u8, session_id: u8) -> bool {
            let session = self.attendance_sessions.entry((bootcamp_id, week, session_id)).read();

            if !session.is_open {
                return false;
            }

            let current_time = get_block_timestamp();
            let end_time = session.opened_at + (session.duration_minutes.into() * 60);

            current_time <= end_time
        }

        fn get_all_attendees(self: @ContractState, bootcamp_id: u256) -> Array<(ContractAddress, AttendeeRecord)> {
            let caller = get_caller_address();
            let _bootcamp = self.bootcamps.entry(bootcamp_id).read();
            let _is_tutor = self.tutors.entry((bootcamp_id, caller)).read();
            
            // Allow organizer or tutors to retrieve attendees
            // assert(bootcamp.organizer == caller || is_tutor, 'Only organizer or tutor allowed');
            
            let attendee_count = self.bootcamp_attendee_count.entry(bootcamp_id).read();
            let mut result = ArrayTrait::new();
            
            let mut i = 0;
            while i != attendee_count {
                let attendee = self.bootcamp_attendee_by_index.entry((bootcamp_id, i)).read();
                let record = self.attendee_records.entry((bootcamp_id, attendee)).read();
                
                if record.is_registered {
                    result.append((attendee, record));
                }
                
                i += 1;
            };
            
            result
        }

        fn get_assignment_info(self: @ContractState, bootcamp_id: u256, week: u8, attendee: ContractAddress) -> AssignmentGrade {
            let grades = self.assignment_grades.entry((bootcamp_id, week, attendee)).read();
            grades
        }

        // This was just for testing purpose
        fn debug_bootcamp_data(self: @ContractState, bootcamp_id: u256) -> (ContractAddress, ContractAddress, ByteArray, bool) {
            let caller = get_caller_address();
            let bootcamp = self.bootcamps.entry(bootcamp_id).read();
            
            (
                caller,                    // Who is calling this function
                bootcamp.organizer,        // Who created the bootcamp
                bootcamp.name.clone(),     // Bootcamp name
                caller == bootcamp.organizer  // Are they the same?
            )
        }

    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn assert_only_owner(self: @ContractState) {
            let owner: ContractAddress = self.owner.read();
            let caller: ContractAddress = get_caller_address();
            assert(!caller.is_zero(), 'Zero address not allowed');
            assert(caller == owner, 'Owner is not the caller');
        }
    }
}