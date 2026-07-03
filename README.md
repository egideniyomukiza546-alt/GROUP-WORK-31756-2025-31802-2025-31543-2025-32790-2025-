# 🎓 Student Course Registration System  
### PL/SQL Group Project – DPR400210: Database Programming

---

## 📌 Overview

This project implements a **simple database application** using **Oracle PL/SQL** to solve a real‑world problem: managing student course registrations at a university.  
The system ensures that:
- Students can enrol in courses only if seats are available.
- Duplicate registrations are prevented.
- Course popularity can be analysed via window functions.
- Total credit load per student is calculated on demand.

All code is written in PL/SQL and is fully documented. The project was developed collaboratively by a group of five students as part of the **Group Assignment III** for the course **DPR400210**.

---

## 🧩 Problem Statement

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

## 🗄️ Database Schema

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

## 🔧 PL/SQL Implementation

The project demonstrates the four required PL/SQL concepts:

### 1. Window Functions
- **File:** `window_functions.sql`
- **Purpose:** Rank courses by number of registered students and show cumulative enrolment trends.
- **Sample Query:**
  ```sql
  SELECT course_id, course_name, 
         COUNT(student_id) AS enrolled,
         RANK() OVER (ORDER BY COUNT(student_id) DESC) AS popularity_rank
  FROM courses c
  LEFT JOIN registrations r USING(course_id)
  GROUP BY course_id, course_name;
