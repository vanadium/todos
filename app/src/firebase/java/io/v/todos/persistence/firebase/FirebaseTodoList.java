// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package io.v.todos.persistence.firebase;

import android.content.Context;

import com.firebase.client.ChildEventListener;
import com.firebase.client.DataSnapshot;
import com.firebase.client.Firebase;
import com.firebase.client.FirebaseError;
import com.firebase.client.ValueEventListener;

import io.v.todos.model.Task;
import io.v.todos.model.TodoList;
import io.v.todos.persistence.TodoListListener;
import io.v.todos.persistence.TodoListPersistence;

public class FirebaseTodoList extends FirebasePersistence implements TodoListPersistence {
    public static final String TASKS = "snackoo lists (Task)";

    private final Firebase mTodoList, mTasks;
    private final ValueEventListener mTodoListListener;
    private final ChildEventListener mTasksListener;

    private TodoList mList;

    public FirebaseTodoList(Context context, String todoListKey, final TodoListListener listener) {
        super(context);

        mTodoList = getFirebase().child(FirebaseMain.TODO_LISTS).child(todoListKey);
        mTasks = getFirebase().child(TASKS).child(todoListKey);

        mTodoListListener = mTodoList.addValueEventListener(new ValueEventListener() {
            @Override
            public void onDataChange(DataSnapshot dataSnapshot) {
                TodoList todoList = dataSnapshot.getValue(TodoList.class);
                if (todoList == null) {
                    listener.onDelete();
                } else {
                    mList = todoList;
                    listener.onUpdate(todoList);
                }
            }

            @Override
            public void onCancelled(FirebaseError firebaseError) {

            }
        });

        mTasksListener = mTasks.addChildEventListener(
                new ChildEventListenerAdapter<>(Task.class, listener));
    }

    @Override
    public void updateTodoList(TodoList todoList) {
        mTodoList.setValue(todoList);
    }

    @Override
    public void deleteTodoList() {
        mTodoList.removeValue();
    }

    @Override
    public void addTask(Task task) {
        mTasks.push().setValue(task);
        mTodoList.setValue(new TodoList(mList.getName()));
    }

    @Override
    public void updateTask(Task task) {
        mTasks.child(task.getKey()).setValue(task);
        mTodoList.setValue(new TodoList(mList.getName()));
    }

    @Override
    public void deleteTask(String key) {
        mTasks.child(key).removeValue();
        mTodoList.setValue(new TodoList(mList.getName()));
    }

    @Override
    public void close() {
        getFirebase().removeEventListener(mTodoListListener);
        getFirebase().removeEventListener(mTasksListener);
    }
}
