package com.secureflow.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.secureflow.model.User;
import com.secureflow.service.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class UserControllerTest {

    @Mock
    private UserService userService;

    @InjectMocks
    private UserController userController;

    private MockMvc mockMvc;
    private ObjectMapper objectMapper;

    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
        mockMvc = MockMvcBuilders.standaloneSetup(userController).build();
        objectMapper = new ObjectMapper();
    }

    @Test
    void getAllUsers_ShouldReturnUserList() throws Exception {
        List<User> users = Arrays.asList(
            new User("user1@example.com", "User One"),
            new User("user2@example.com", "User Two")
        );
        when(userService.getAllUsers()).thenReturn(users);

        mockMvc.perform(get("/api/users"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$[0].email").value("user1@example.com"))
            .andExpect(jsonPath("$[1].email").value("user2@example.com"));

        verify(userService, times(1)).getAllUsers();
    }

    @Test
    void getUserById_WhenUserExists_ShouldReturnUser() throws Exception {
        User user = new User("test@example.com", "Test User");
        user.setId(1L);
        when(userService.getUserById(1L)).thenReturn(Optional.of(user));

        mockMvc.perform(get("/api/users/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(1))
            .andExpect(jsonPath("$.email").value("test@example.com"));

        verify(userService, times(1)).getUserById(1L);
    }

    @Test
    void getUserById_WhenUserNotExists_ShouldReturn404() throws Exception {
        when(userService.getUserById(999L)).thenReturn(Optional.empty());

        mockMvc.perform(get("/api/users/999"))
            .andExpect(status().isNotFound());

        verify(userService, times(1)).getUserById(999L);
    }

    @Test
    void createUser_ShouldReturnCreatedUser() throws Exception {
        User user = new User("new@example.com", "New User");
        User createdUser = new User("new@example.com", "New User");
        createdUser.setId(1L);
        
        when(userService.createUser(any(User.class))).thenReturn(createdUser);

        mockMvc.perform(post("/api/users")
            .contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(user)))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value(1))
            .andExpect(jsonPath("$.email").value("new@example.com"));

        verify(userService, times(1)).createUser(any(User.class));
    }

    @Test
    void updateUser_WhenUserExists_ShouldReturnUpdatedUser() throws Exception {
        User userDetails = new User("updated@example.com", "Updated User");
        User updatedUser = new User("updated@example.com", "Updated User");
        updatedUser.setId(1L);
        
        when(userService.updateUser(eq(1L), any(User.class))).thenReturn(updatedUser);

        mockMvc.perform(put("/api/users/1")
            .contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(userDetails)))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.id").value(1))
            .andExpect(jsonPath("$.email").value("updated@example.com"));

        verify(userService, times(1)).updateUser(eq(1L), any(User.class));
    }

    @Test
    void updateUser_WhenUserNotExists_ShouldReturn404() throws Exception {
        User userDetails = new User("updated@example.com", "Updated User");
        when(userService.updateUser(eq(999L), any(User.class))).thenReturn(null);

        mockMvc.perform(put("/api/users/999")
            .contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(userDetails)))
            .andExpect(status().isNotFound());

        verify(userService, times(1)).updateUser(eq(999L), any(User.class));
    }

    @Test
    void deleteUser_WhenUserExists_ShouldReturn204() throws Exception {
        when(userService.deleteUser(1L)).thenReturn(true);

        mockMvc.perform(delete("/api/users/1"))
            .andExpect(status().isNoContent());

        verify(userService, times(1)).deleteUser(1L);
    }

    @Test
    void deleteUser_WhenUserNotExists_ShouldReturn404() throws Exception {
        when(userService.deleteUser(999L)).thenReturn(false);

        mockMvc.perform(delete("/api/users/999"))
            .andExpect(status().isNotFound());

        verify(userService, times(1)).deleteUser(999L);
    }
}
