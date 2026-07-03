# Student Course Registration System  
### PL/SQL Group Project – DPR400210: Database Programming

---

## Overview

This project implements a **simple database application** using **Oracle PL/SQL** to solve a real‑world problem: managing student course registrations at a university.  
The system ensures that:
- Students can enrol in courses only if seats are available.
- Duplicate registrations are prevented.
- Course popularity can be analysed via window functions.
- Total credit load per student is calculated on demand.

All code is written in PL/SQL and is fully documented. The project was developed collaboratively by a group of five students as part of the **Group Assignment III** for the course **DPR400210**.

---

##  Problem Statement

Universities often manage course registrations manually or with spreadsheets, leading to:
- Over‑enrolment beyond seat capacity.
- Duplicate records.
- Difficulty in tracking student credit totals.
- No easy way to identify popular courses.

Our system provides a **relational database** with a set of **PL/SQL programs** that:

1. **Store** students, courses, and registrations.
2. **Enforce** seat limits using transactional logic.
3. **Rank** courses by enrolment numbers using window functions.
4. **Calculate** total credits per student with a function.
5. **Automate** enrolment with a stored procedure that handles errors gracefully.

---

##  Database Schema

The database consists of three tables with proper constraints.

### Table: `students`
| Column        | Type          | Description                | Constraints         |
|---------------|---------------|----------------------------|---------------------|
| `student_id`  | NUMBER        | Unique student identifier  | PRIMARY KEY         |
| `first_name`  | VARCHAR2(50)  | Student’s first name       | NOT NULL            |
| `last_name`   | VARCHAR2(50)  | Student’s last name        | NOT NULL            |
| `email`       | VARCHAR2(100) | Unique email address       | NOT NULL, UNIQUE    |
| `enrolled_date`| DATE          | Date of enrolment          | DEFAULT SYSDATE     |

### Table: `courses`
| Column          | Type          | Description                     | Constraints               |
|-----------------|---------------|---------------------------------|---------------------------|
| `course_id`     | NUMBER        | Unique course identifier       | PRIMARY KEY               |
| `course_name`   | VARCHAR2(100) | Full course title               | NOT NULL                  |
| `credits`       | NUMBER(2)     | Credit value of the course      | NOT NULL, CHECK > 0       |
| `max_seats`     | NUMBER(3)     | Maximum capacity                | NOT NULL, CHECK > 0       |
| `available_seats`| NUMBER(3)    | Currently free seats            | NOT NULL, CHECK >= 0      |

### Table: `registrations`
| Column            | Type          | Description                         | Constraints                              |
|-------------------|---------------|-------------------------------------|------------------------------------------|
| `registration_id` | NUMBER        | Unique registration identifier      | PRIMARY KEY                              |
| `student_id`      | NUMBER        | References `students(student_id)`   | FOREIGN KEY, NOT NULL                    |
| `course_id`       | NUMBER        | References `courses(course_id)`     | FOREIGN KEY, NOT NULL                    |
| `registration_date`| DATE         | Date of registration                | DEFAULT SYSDATE                          |
| `grade`           | NUMBER(5,2)   | Final grade (nullable)              | CHECK BETWEEN 0 AND 100                  |
| Unique constraint | (student_id, course_id) | Prevents duplicate registrations | UNIQUE                                   |

---

## 🔧 PL/SQL Implementation – Full Code

Below is the **complete implementation** for all four required concepts.

---

1️⃣ Window Functions
File: window_functions.sql
Purpose: Rank courses by number of registered students, show cumulative enrolment trends, and analyse student registration patterns.
```sql

   -- ------------------------------------------------------------
-- 1. Basic Ranking - Rank courses by enrolment count
-- ------------------------------------------------------------
SELECT 
    c.course_id,
    c.course_name,
    c.credits,
    COUNT(r.student_id) AS enrolled_students,
    RANK() OVER (ORDER BY COUNT(r.student_id) DESC) AS popularity_rank,
    DENSE_RANK() OVER (ORDER BY COUNT(r.student_id) DESC) AS dense_popularity_rank,
    ROW_NUMBER() OVER (ORDER BY COUNT(r.student_id) DESC, c.course_name) AS row_number
FROM 
    courses c
LEFT JOIN 
    registrations r ON c.course_id = r.course_id
GROUP BY 
    c.course_id, c.course_name, c.credits
ORDER BY 
    popularity_rank;

-- ------------------------------------------------------------
-- 2. Ranking with partition by course credits
--    Shows ranking within each credit group (e.g., 3-credit courses)
-- ------------------------------------------------------------
SELECT 
    c.course_id,
    c.course_name,
    c.credits,
    COUNT(r.student_id) AS enrolled_students,
    RANK() OVER (PARTITION BY c.credits ORDER BY COUNT(r.student_id) DESC) AS rank_within_credit_group
FROM 
    courses c
LEFT JOIN 
    registrations r ON c.course_id = r.course_id
GROUP BY 
    c.course_id, c.course_name, c.credits
ORDER BY 
    c.credits, rank_within_credit_group;

-- ------------------------------------------------------------
-- 3. Cumulative registrations over time (running total)
-- ------------------------------------------------------------
SELECT 
    TRUNC(r.registration_date) AS reg_date,
    COUNT(*) AS daily_registrations,
    SUM(COUNT(*)) OVER (ORDER BY TRUNC(r.registration_date) 
                        ROWS UNBOUNDED PRECEDING) AS cumulative_registrations
FROM 
    registrations r
GROUP BY 
    TRUNC(r.registration_date)
ORDER BY 
    reg_date;

-- ------------------------------------------------------------
-- 4. Top 3 most popular courses using ROW_NUMBER filter
-- ------------------------------------------------------------
WITH ranked_courses AS (
    SELECT 
        c.course_id,
        c.course_name,
        COUNT(r.student_id) AS enrolled,
        ROW_NUMBER() OVER (ORDER BY COUNT(r.student_id) DESC) AS row_num
    FROM 
        courses c
    LEFT JOIN 
        registrations r ON c.course_id = r.course_id
    GROUP BY 
        c.course_id, c.course_name
)
SELECT 
    course_id,
    course_name,
    enrolled,
    row_num AS rank_position
FROM 
    ranked_courses
WHERE 
    row_num <= 3
ORDER BY 
    row_num;

-- ------------------------------------------------------------
-- 5. Each student's registration count and ranking
--    (Who has the most courses?)
-- ------------------------------------------------------------
SELECT 
    s.student_id,
    s.first_name || ' ' || s.last_name AS full_name,
    COUNT(r.course_id) AS courses_taken,
    RANK() OVER (ORDER BY COUNT(r.course_id) DESC) AS registration_rank
FROM 
    students s
LEFT JOIN 
    registrations r ON s.student_id = r.student_id
GROUP BY 
    s.student_id, s.first_name, s.last_name
ORDER BY 
    registration_rank;
```

2️⃣ Anonymous Block
File: anonymous_block.sql
Purpose: Perform a single enrolment transaction with full validation and error handling, without creating a persistent procedure. Perfect for ad‑hoc operations.

 ```sql
SET SERVEROUTPUT ON;

DECLARE
    -- Input parameters (modify these to test different scenarios)
    v_student_id    NUMBER := 110;   
    v_course_id     NUMBER := 203;   
    
    -- Local variables
    v_available     NUMBER;
    v_max_seats     NUMBER;
    v_reg_id        NUMBER;
    v_exists        NUMBER;
    
    -- Custom exceptions
    e_course_full   EXCEPTION;
    e_duplicate     EXCEPTION;
    e_student_not_found EXCEPTION;
    e_course_not_found EXCEPTION;
    
    PRAGMA EXCEPTION_INIT(e_course_full, -20001);
    PRAGMA EXCEPTION_INIT(e_duplicate, -20002);
    PRAGMA EXCEPTION_INIT(e_student_not_found, -20003);
    PRAGMA EXCEPTION_INIT(e_course_not_found, -20004);

BEGIN
    -- Step 1: Validate student exists
    SELECT COUNT(*) INTO v_exists
    FROM students
    WHERE student_id = v_student_id;
    
    IF v_exists = 0 THEN
        RAISE e_student_not_found;
    END IF;

    -- Step 2: Get course details with row lock (FOR UPDATE)
    SELECT available_seats, max_seats 
    INTO v_available, v_max_seats
    FROM courses
    WHERE course_id = v_course_id
    FOR UPDATE;
    
    -- Step 3: Check course capacity
    IF v_available <= 0 THEN
        RAISE e_course_full;
    END IF;

    -- Step 4: Check duplicate registration
    SELECT COUNT(*) INTO v_exists
    FROM registrations
    WHERE student_id = v_student_id AND course_id = v_course_id;
    
    IF v_exists > 0 THEN
        RAISE e_duplicate;
    END IF;

    -- Step 5: Generate new registration ID (manual method)
    SELECT NVL(MAX(registration_id), 0) + 1 
    INTO v_reg_id
    FROM registrations;

    -- Step 6: Insert registration and update seats
    INSERT INTO registrations (registration_id, student_id, course_id, registration_date)
    VALUES (v_reg_id, v_student_id, v_course_id, SYSDATE);
    
    UPDATE courses 
    SET available_seats = available_seats - 1
    WHERE course_id = v_course_id;

    -- Step 7: Commit and report
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE(' SUCCESS: Student ' || v_student_id || 
                         ' enrolled in course ' || v_course_id || 
                         '. Seats left: ' || (v_available - 1));

EXCEPTION
    WHEN e_student_not_found THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' ERROR: Student ID ' || v_student_id || ' does not exist.');
    
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' ERROR: Course ID ' || v_course_id || ' does not exist.');
    
    WHEN e_course_full THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' ERROR: Course ' || v_course_id || 
                             ' is full (max: ' || v_max_seats || ').');
    
    WHEN e_duplicate THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' ERROR: Student ' || v_student_id || 
                             ' is already registered for course ' || v_course_id || '.');
    
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' UNEXPECTED ERROR: ' || SQLERRM);
END;
/
```
3️⃣ Stored Procedure – enrol_student
File: procedure.sql
Purpose: Reusable, production‑ready procedure to enrol a student into a course. Includes comprehensive error handling, row‑level locking, and clear user feedback

```sql
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
    
    PRAGMA EXCEPTION_INIT(e_course_full, -20001);
    PRAGMA EXCEPTION_INIT(e_duplicate, -20002);
    PRAGMA EXCEPTION_INIT(e_invalid_student, -20003);
    PRAGMA EXCEPTION_INIT(e_invalid_course, -20004);

BEGIN
    -- Step 1: Validate that the student exists
    SELECT COUNT(*) INTO v_student_exists
    FROM students
    WHERE student_id = p_student_id;
    
    IF v_student_exists = 0 THEN
        RAISE e_invalid_student;
    END IF;

    -- Step 2: Validate course and get seat info (FOR UPDATE locks the row)
    SELECT available_seats, max_seats 
    INTO v_available, v_max_seats
    FROM courses
    WHERE course_id = p_course_id
    FOR UPDATE;

    -- Step 3: Check if course is full
    IF v_available <= 0 THEN
        RAISE e_course_full;
    END IF;

    -- Step 4: Explicit check for duplicate registration
    SELECT COUNT(*) INTO v_student_exists
    FROM registrations
    WHERE student_id = p_student_id AND course_id = p_course_id;
    
    IF v_student_exists > 0 THEN
        RAISE e_duplicate;
    END IF;

    -- Step 5: Generate a new registration ID (manual method)
    SELECT NVL(MAX(registration_id), 0) + 1 
    INTO v_registration_id
    FROM registrations;

    -- Step 6: Insert the registration
    INSERT INTO registrations (registration_id, student_id, course_id, registration_date)
    VALUES (v_registration_id, p_student_id, p_course_id, SYSDATE);

    -- Step 7: Decrement available seats
    UPDATE courses 
    SET available_seats = available_seats - 1
    WHERE course_id = p_course_id;

    -- Step 8: Commit the transaction
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE(' Success: Student ' || p_student_id || 
                         ' enrolled in course ' || p_course_id || 
                         '. Remaining seats: ' || (v_available - 1));

EXCEPTION
    WHEN e_course_full THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' Error: Course ' || p_course_id || 
                             ' is full (max seats: ' || v_max_seats || ').');
        RAISE_APPLICATION_ERROR(-20001, 'Course is full');

    WHEN e_duplicate THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' Error: Student ' || p_student_id || 
                             ' is already registered for course ' || p_course_id || '.');
        RAISE_APPLICATION_ERROR(-20002, 'Duplicate registration');

    WHEN e_invalid_student THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('❌ Error: Student ID ' || p_student_id || ' does not exist.');
        RAISE_APPLICATION_ERROR(-20003, 'Invalid student ID');

    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' Error: Course ID ' || p_course_id || ' does not exist.');
        RAISE_APPLICATION_ERROR(-20004, 'Invalid course ID');

    WHEN DUP_VAL_ON_INDEX THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' Error: Duplicate registration (unique constraint violated).');
        RAISE_APPLICATION_ERROR(-20002, 'Duplicate registration');

    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE(' Unexpected error: ' || SQLERRM);
        RAISE;
END enrol_student;
/
```
4️⃣ User‑defined Function – get_total_credits

File: function.sql

Purpose: Returns the total number of credits a student has accumulated from all registered courses. Can be used in SQL queries or other PL/SQL blocks.

```sql
CREATE OR REPLACE FUNCTION get_total_credits (
    p_student_id IN NUMBER
) RETURN NUMBER
IS
    v_total_credits NUMBER := 0;
    v_student_exists NUMBER;
    e_student_not_found EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_student_not_found, -20005);
BEGIN
    -- Validate that the student exists
    SELECT COUNT(*) INTO v_student_exists
    FROM students
    WHERE student_id = p_student_id;
    
    IF v_student_exists = 0 THEN
        RAISE e_student_not_found;
    END IF;

    -- Compute total credits from registrations (returns 0 if none)
    SELECT NVL(SUM(c.credits), 0)
    INTO v_total_credits
    FROM registrations r
    JOIN courses c ON r.course_id = c.course_id
    WHERE r.student_id = p_student_id;
    
    RETURN v_total_credits;

EXCEPTION
    WHEN e_student_not_found THEN
        RAISE_APPLICATION_ERROR(-20005, 'Student ID ' || p_student_id || ' does not exist.');
    WHEN OTHERS THEN
        RAISE;
END get_total_credits;
/
```
