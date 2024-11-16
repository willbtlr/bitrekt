from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

app = FastAPI(title="Sample API", description="A simple API with FastAPI")

# Pydantic models
class Task(BaseModel):
    id: Optional[int] = None
    title: str
    bar: str
    foo: str
    description: str
    completed: bool = False
    created_at: Optional[datetime] = None

class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    completed: Optional[bool] = None

# In-memory database
tasks_db: dict[int, Task] = {}
task_counter = 1

# Routes
@app.get("/")
async def root():
    """Return a welcome message"""
    return {"message": "Welcome to the Task API"}

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now(),
        "version": "1.0.0"
    }

@app.get("/tasks", response_model=List[Task])
async def get_tasks(
    skip: int = Query(default=0, ge=0),
    limit: int = Query(default=10, ge=1, le=100),
    completed: Optional[bool] = None
):
    """Get all tasks with optional filtering and pagination"""
    tasks = list(tasks_db.values())
    
    if completed is not None:
        tasks = [task for task in tasks if task.completed == completed]
    
    return tasks[skip : skip + limit]

@app.get("/tasks/{task_id}", response_model=Task)
async def get_task(task_id: int):
    """Get a specific task by ID"""
    if task_id not in tasks_db:
        raise HTTPException(status_code=404, detail="Task not found")
    return tasks_db[task_id]

@app.post("/tasks", response_model=Task, status_code=201)
async def create_task(task: Task):
    """Create a new task"""
    global task_counter
    
    task.id = task_counter
    task.created_at = datetime.now()
    tasks_db[task_counter] = task
    task_counter += 1
    
    return task

@app.patch("/tasks/{task_id}", response_model=Task)
async def update_task(task_id: int, task_update: TaskUpdate):
    """Update a task partially"""
    if task_id not in tasks_db:
        raise HTTPException(status_code=404, detail="Task not found")
    
    stored_task = tasks_db[task_id]
    update_data = task_update.dict(exclude_unset=True)
    
    for field, value in update_data.items():
        setattr(stored_task, field, value)
    
    return stored_task

@app.delete("/tasks/{task_id}")
async def delete_task(task_id: int):
    """Delete a task"""
    if task_id not in tasks_db:
        raise HTTPException(status_code=404, detail="Task not found")
    
    del tasks_db[task_id]
    return {"message": "Task deleted successfully"}

@app.get("/tasks/search")
async def search_tasks(q: str = Query(..., min_length=3)):
    """Search tasks by title or description"""
    matching_tasks = [
        task for task in tasks_db.values()
        if q.lower() in task.title.lower() or q.lower() in task.description.lower()
    ]
    return matching_tasks

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
