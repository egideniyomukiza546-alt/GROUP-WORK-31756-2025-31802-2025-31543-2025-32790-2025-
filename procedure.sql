
-- STORED PROCEDURE: enrol_student


-- ------------------------------------------------------------
-- 2. CREATE PROCEDURE
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE enrol_student (
    p_student_id IN NUMBER,
    p_course_id  IN NUMBER
) AS
    -- Local variables
    v_available        NUMBER;
    v_max_seats        NUMBER;
    v_registration_id  NUMBER;
    v_student_exists   NUMBER;
    v_course_exists    NUMBER;
    
    -- Custom exceptions
    e_course_full      EXCEPTION;
    e_duplicate        EXCEPTION;
    e_invalid_student  EXCEPTION;
    e_invalid_course   EXCEPTION;
    
    -- PRAGMA to assign error codes for custom exceptions
    PRAGMA EXCEPTION_INIT(e_course_full, -20001);
    PRAGMA EXCEPTION_INIT(e_duplicate, -20002);
    PRAGMA EXCEPTION_INIT(e_invalid_student, -20003);
    PRAGMA EXCEPTION_INIT(e_invalid_course, -20004);

BEGIN
    -- --------------------------------------------------------
    -- Step 1: Validate that the student exists
    -- --------------------------------------------------------
    SELECT COUNT(*) INTO v_student_exists
    FROM students
    WHERE student_id = p_student_id;
    
    IF v_student_exists = 0 THEN
        RAISE e_invalid_student;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Validate that the course exists and get seat info
    --         FOR UPDATE locks the row to prevent race conditions
    -- --------------------------------------------------------
    SELECT available_seats, max_seats 
    INTO v_available, v_max_seats
    FROM courses
    WHERE course_id = p_course_id
    FOR UPDATE;
    
    -- If no row found, the SELECT INTO will raise NO_DATA_FOUND
    -- which we catch in the EXCEPTION block.

    -- --------------------------------------------------------
    -- Step 3: Check if course is full
    -- --------------------------------------------------------
    IF v_available <= 0 THEN
        RAISE e_course_full;
    END IF;

    -- --------------------------------------------------------
    -- Step 4: Check for duplicate registration (implicitly via unique constraint)
    --         We can also do an explicit check to give a clearer message.
    -- --------------------------------------------------------
    BEGIN
        SELECT COUNT(*) INTO v_student_exists
        FROM registrations
        WHERE student_id = p_student_id AND course_id = p_course_id;
        
        IF v_student_exists > 0 THEN
            RAISE e_duplicate;
        END IF;
    EXCEPTION
        WHEN e_duplicate THEN
            RAISE;  -- re-raise to outer block
        WHEN NO_DATA_FOUND THEN
            NULL;   -- no duplicate, continue
    END;

    -- --------------------------------------------------------
    -- Step 5: Generate a new registration ID (manual method)
    --         If you use sequences, replace this with seq_registration_id.NEXTVAL
    -- --------------------------------------------------------
    SELECT NVL(MAX(registration_id), 0) + 1 
    INTO v_registration_id
    FROM registrations;

    -- --------------------------------------------------------
    -- Step 6: Insert the registration
    -- --------------------------------------------------------
    INSERT INTO registrations (registration_id, student_id, course_id, registration_date)
    VALUES (v_registration_id, p_student_id, p_course_id, SYSDATE);

    -- --------------------------------------------------------
    -- Step 7: Decrement available seats
    -- --------------------------------------------------------
    UPDATE courses 
    SET available_seats = available_seats - 1
    WHERE course_id = p_course_id;

    -- --------------------------------------------------------
    -- Step 8: Commit the transaction
    -- --------------------------------------------------------
    COMMIT;
    
    -- Output success message
    DBMS_OUTPUT.PUT_LINE(' Success: Student ' || p_student_id || 
                         ' enrolled in course ' || p_course_id || 
                         '. Remaining seats: ' || (v_available - 1));

-- ------------------------------------------------------------
-- 3. EXCEPTION HANDLING
-- ------------------------------------------------------------
EXCEPTION
    -- Course full
    WHEN e_course_full THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' Error: Course ' || p_course_id || 
                             ' is full (max seats: ' || v_max_seats || ').');
        RAISE_APPLICATION_ERROR(-20001, 'Course is full');

    -- Duplicate registration
    WHEN e_duplicate THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' Error: Student ' || p_student_id || 
                             ' is already registered for course ' || p_course_id || '.');
        RAISE_APPLICATION_ERROR(-20002, 'Duplicate registration');

    -- Student does not exist
    WHEN e_invalid_student THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' Error: Student ID ' || p_student_id || ' does not exist.');
        RAISE_APPLICATION_ERROR(-20003, 'Invalid student ID');

    -- Course does not exist
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' Error: Course ID ' || p_course_id || ' does not exist.');
        RAISE_APPLICATION_ERROR(-20004, 'Invalid course ID');

    -- Any other unexpected error (e.g., unique constraint violation from the index)
    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' Error: Duplicate registration (unique constraint violated).');
        RAISE_APPLICATION_ERROR(-20002, 'Duplicate registration');

    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' Unexpected error: ' || SQLERRM);
        RAISE;  -- re-raise the original error

END enrol_student;
/

-- ------------------------------------------------------------
-- 4. Verify procedure compilation
-- ------------------------------------------------------------
SHOW ERRORS PROCEDURE enrol_student;

-- ------------------------------------------------------------
-- 5. TEST EXECUTION (optional – run this to test the procedure)
--    Uncomment the block below to run tests after creation.
-- ------------------------------------------------------------
/*
SET SERVEROUTPUT ON;

BEGIN
    -- Test 1: Enrol student 110 into course 203 (has 2 available seats)
    enrol_student(110, 203);
END;
/

BEGIN
    -- Test 2: Try to enrol student 110 into course 201 (full)
    enrol_student(110, 201);
END;
/

BEGIN
    -- Test 3: Try to enrol student 110 into course 203 again (duplicate)
    enrol_student(110, 203);
END;
/

BEGIN
    -- Test 4: Try with invalid student ID (999)
    enrol_student(999, 203);
END;
/

BEGIN
    -- Test 5: Try with invalid course ID (999)
    enrol_student(110, 999);
END;
/
*/

-- ------------------------------------------------------------
-- 6. Display current state for verification
-- ------------------------------------------------------------
PROMPT ===============================================
PROMPT Procedure created successfully!
PROMPT Use: EXEC enrol_student(student_id, course_id);
PROMPT ===============================================

-- Check current available seats for testing reference
SELECT course_id, course_name, available_seats, max_seats
FROM courses
ORDER BY course_id;
