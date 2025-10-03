# Decentralized Task Management Protocol

A blockchain-based smart contract system for distributed team coordination featuring automated task assignment, milestone tracking, reputation scoring, and cryptocurrency-based compensation for remote workers and decentralized autonomous organizations (DAOs).

## Overview

This smart contract provides a complete solution for managing projects and tasks on the Stacks blockchain. It enables project owners to create projects, assign tasks to team members, track progress, and automatically compensate contributors upon task completion while maintaining a reputation system for all participants.

## Key Features

- **Project Management**: Create and manage multiple projects with allocated budgets
- **Team Collaboration**: Add up to 20 team members per project
- **Task Assignment**: Create and assign tasks with deadlines and compensation amounts
- **Automated Payments**: Automatic STX token transfers upon task completion
- **Reputation System**: Track contributor performance and ratings
- **Access Control**: Role-based permissions for owners and team members
- **Status Tracking**: Monitor project and task status throughout lifecycle

## Core Components

### Data Structures

**Projects**
- Unique project identifier
- Owner principal address
- Title and description
- Allocated budget
- Current status
- Creation block height
- Team member list (max 20)

**Tasks**
- Project and task identifiers
- Assigned contributor
- Title and description
- Due block height
- Compensation amount
- Current status
- Creation block height

**Contributor Profiles**
- Tasks completed count
- Total earnings
- Reputation score (1-5 scale)
- Total ratings received

## Constants

### Error Codes
- `ERR-UNAUTHORIZED-ACCESS (u100)`: User lacks required permissions
- `ERR-PROJECT-NOT-FOUND (u101)`: Project does not exist
- `ERR-TASK-NOT-FOUND (u102)`: Task does not exist
- `ERR-INVALID-STATUS-TRANSITION (u103)`: Invalid status change
- `ERR-INSUFFICIENT-FUNDS (u104)`: Inadequate balance for operation
- `ERR-PROJECT-ALREADY-EXISTS (u105)`: Duplicate project creation
- `ERR-TASK-ALREADY-EXISTS (u106)`: Duplicate task creation
- `ERR-INVALID-INPUT (u107)`: Invalid function parameters
- `ERR-MEMBER-ALREADY-ADDED (u108)`: Team member already exists
- `ERR-TEAM-CAPACITY-EXCEEDED (u109)`: Team size limit reached

### Configuration
- `max-team-size`: 20 members per project
- `min-reputation-score`: 1
- `max-reputation-score`: 5
- Status values: "active", "pending", "completed"

## Public Functions

### create-project
Creates a new project with allocated budget.

**Parameters:**
- `title` (string-ascii 50): Project title
- `description` (string-ascii 500): Project description
- `budget` (uint): Allocated project budget in STX

**Returns:** Project ID (uint)

**Authorization:** Any user

### add-member
Adds a contributor to the project team.

**Parameters:**
- `project-id` (uint): Target project identifier
- `member` (principal): Address of team member to add

**Returns:** Boolean success indicator

**Authorization:** Project owner only

### assign-task
Creates and assigns a new task to a team member.

**Parameters:**
- `project-id` (uint): Target project identifier
- `title` (string-ascii 50): Task title
- `description` (string-ascii 500): Task description
- `assignee` (principal): Team member to assign task
- `deadline` (uint): Due block height
- `payment` (uint): Compensation amount in STX

**Returns:** Task ID (uint)

**Authorization:** Project owner only

**Validation:**
- Assignee must be project owner or team member
- Deadline must be in the future
- Payment must be greater than zero

### update-task-status
Updates the status of an existing task.

**Parameters:**
- `project-id` (uint): Target project identifier
- `task-id` (uint): Target task identifier
- `new-status` (string-ascii 20): New status value

**Returns:** Boolean success indicator

**Authorization:** Project owner or task assignee

### complete-task-with-payment
Marks task as completed and transfers compensation to assignee.

**Parameters:**
- `project-id` (uint): Target project identifier
- `task-id` (uint): Target task identifier

**Returns:** Boolean success indicator

**Authorization:** Task assignee only

**Effects:**
- Transfers STX from project owner to assignee
- Updates task status to "completed"
- Increments contributor metrics

### rate-contributor
Submits a reputation rating for a contributor.

**Parameters:**
- `contributor` (principal): Address of contributor to rate
- `rating` (uint): Rating value (1-5)

**Returns:** Boolean success indicator

**Authorization:** Any user

## Read-Only Functions

### get-project-details
Retrieves complete project information.

**Parameters:**
- `project-id` (uint): Target project identifier

**Returns:** Project data structure or none

### get-task-details
Retrieves task information.

**Parameters:**
- `project-id` (uint): Target project identifier
- `task-id` (uint): Target task identifier

**Returns:** Task data structure or none

### get-contributor-profile
Retrieves contributor performance metrics.

**Parameters:**
- `contributor` (principal): Address of contributor

**Returns:** Profile data structure or none

### verify-project-access
Checks if user has access to project (owner or team member).

**Parameters:**
- `project-id` (uint): Target project identifier
- `user` (principal): Address to verify

**Returns:** Boolean access indicator

### verify-project-ownership
Checks if user is the project owner.

**Parameters:**
- `project-id` (uint): Target project identifier
- `user` (principal): Address to verify

**Returns:** Boolean ownership indicator

## Usage Example

```clarity
;; Create a new project
(contract-call? .task-management create-project 
  "DeFi Dashboard" 
  "Build a user-friendly DeFi analytics dashboard" 
  u10000000)
;; Returns: (ok u0)

;; Add team member
(contract-call? .task-management add-member 
  u0 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
;; Returns: (ok true)

;; Assign task
(contract-call? .task-management assign-task 
  u0 
  "Design UI mockups" 
  "Create high-fidelity mockups for main dashboard views" 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
  u1000 
  u500000)
;; Returns: (ok u0)

;; Complete task (as assignee)
(contract-call? .task-management complete-task-with-payment u0 u0)
;; Returns: (ok true)

;; Rate contributor
(contract-call? .task-management rate-contributor 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 
  u5)
;; Returns: (ok true)
```

## Security Considerations

- All state-changing functions include input validation
- Access control enforced through owner and team member checks
- Automatic payment transfers use native STX transfer functionality
- Team size limited to prevent excessive gas costs
- Reputation scores bounded to valid range (1-5)

## Limitations

- Maximum 20 team members per project
- Task assignees must be added to team before assignment
- No task deletion functionality (status updates only)
- No project budget tracking or enforcement
- No dispute resolution mechanism
- Reputation system allows unlimited ratings from any address