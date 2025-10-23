# Care Bridge - Database Structure

## Firestore Collections

### 1. `users` (ASHA Workers)
{
"uid": "firebase_auth_uid",
"fullName": "Jane Doe",
"ashaId": "ASHA-1234",
"email": "jane@example.com",
"phone": "1234567890",
"location": "Mumbai Central",
"phcName": "PHC Mumbai Central",
"role": "ASHA",
"createdAt": "Timestamp",
"createdBy": "phc_staff_uid"
}


### 2. `phc_staff` (PHC Staff Members)
{
"uid": "firebase_auth_uid",
"fullName": "Dr. Smith",
"email": "smith@phc.gov.in",
"phcName": "PHC Mumbai Central",
"location": "Mumbai Central",
"role": "PHC",
"createdAt": "Timestamp"
}


### 3. `inventory_requests` (Inventory Approval Requests)
{
"ashaId": "ASHA-1234",
"ashaName": "Jane Doe",
"location": "Mumbai Central",
"vaccineName": "BCG",
"quantity": 50,
"reason": "Low stock for upcoming vaccination drive",
"status": "pending|approved|rejected",
"requestedAt": "Timestamp",
"approvedAt": "Timestamp (if approved)",
"rejectedAt": "Timestamp (if rejected)",
"rejectionReason": "string (if rejected)"
}


### 4. `inventory` (ASHA Worker Inventory)
{
"ashaId_as_doc_id": {
"BCG": 25,
"OPV": 30,
"DPT": 15,
"Measles": 20,
"Hepatitis B": 10
}
}


### 5. `appointments` (Vaccination Appointments)
{
"ashaId": "ASHA-1234",
"childName": "Baby Kumar",
"age": "6",
"vaccination": "BCG",
"address": "123 Main St",
"phone": "9876543210",
"date": "2025-10-15",
"status": "pending|done",
"completedAt": "Timestamp (if done)",
"createdAt": "Timestamp"
}


### 6. `visits` (Archived Completed Appointments)
{
"ashaId": "ASHA-1234",
"childName": "Baby Kumar",
"vaccination": "BCG",
"age": "6",
"address": "123 Main St",
"phone": "9876543210",
"date": "2025-10-15",
"appointmentId": "original_appointment_id",
"completedAt": "Timestamp",
"archivedAt": "Timestamp",
"createdAt": "Timestamp"
}


## Location-Based Access

- **PHC Staff**: Can only see/manage ASHA workers and requests from their `location`
- **ASHA Workers**: Assigned to a specific `location` and `phcName` during registration
- All inventory requests are filtered by `location` for PHC approval

## User Roles

1. **ASHA Worker (`role: "ASHA"`)**
   - Registered by PHC Staff
   - Manages appointments and vaccinations
   - Submits inventory requests to PHC
   - Views accepted requests

2. **PHC Staff (`role: "PHC"`)**
   - Registers ASHA workers
   - Approves/rejects inventory requests
   - Monitors inventory across all ASHA workers in their location
   - Views statistics and reports

## Request Workflow

1. ASHA Worker creates inventory request → Status: `pending`
2. Request appears in PHC Staff's pending approvals (filtered by location)
3. PHC Staff approves → Status: `approved`, inventory added to ASHA's stock
4. OR PHC Staff rejects → Status: `rejected`, with reason
5. ASHA Worker sees request in "Accepted Requests" or gets rejection notification
