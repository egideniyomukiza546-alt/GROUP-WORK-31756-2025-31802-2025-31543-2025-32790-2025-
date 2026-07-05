-- ============================================================
-- WINDOW FUNCTIONS: Course Popularity Ranking
-- Course: DPR400210 – Database Programming
-- Author: Group Assignment III
-- Date: July 2026
-- ============================================================
-- Description:
--   This script demonstrates the use of window functions
--   (RANK, DENSE_RANK, ROW_NUMBER) to analyze course
--   registration data. It ranks courses by popularity
--   based on the number of enrolled students.



-- 1. Basic Ranking - Rank courses by enrolment count

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


-- 2. Ranking with partition by course credits
--    Shows ranking within each credit group

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


-- 3. Cumulative registrations over time (running total)
--    Shows total registrations per day

SELECT
    TRUNC(r.registration_date) AS reg_date,
    COUNT(*) AS daily_registrations,
    SUM(COUNT(*)) OVER (
        ORDER BY TRUNC(r.registration_date)
        ROWS UNBOUNDED PRECEDING
    ) AS cumulative_registrations
FROM registrations r
GROUP BY TRUNC(r.registration_date)
ORDER BY reg_date;

-- 4. Top 3 most popular courses using ROW_NUMBER filter

WITH ranked_courses AS (
    SELECT 
        c.course_id,
        c.course_name,
        COUNT(r.student_id) AS enrolled,
        ROW_NUMBER() OVER (
            ORDER BY COUNT(r.student_id) DESC
        ) AS row_num
    FROM courses c
    LEFT JOIN registrations r
        ON c.course_id = r.course_id
    GROUP BY c.course_id, c.course_name
)
SELECT 
    course_id,
    course_name,
    enrolled,
    row_num AS rank_position
FROM ranked_courses
WHERE row_num <= 3
ORDER BY row_num;


-- 5. Each student's registration count and ranking within the class
--    (Who has the most courses?)

SELECT 
    s.student_id,
    s.first_name || ' ' || s.last_name AS full_name,
    COUNT(r.course_id) AS courses_taken,
    RANK() OVER (ORDER BY COUNT(r.course_id) DESC) AS registration_rank
FROM students s
LEFT JOIN registrations r 
    ON s.student_id = r.student_id
GROUP BY 
    s.student_id, s.first_name, s.last_name
ORDER BY 
    registration_rank;


PROMPT Window function queries executed.
PROMPT Review output for course popularity insights.
