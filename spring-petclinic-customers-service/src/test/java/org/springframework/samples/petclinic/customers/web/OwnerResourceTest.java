package org.springframework.samples.petclinic.customers.web;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.samples.petclinic.customers.model.Owner;
import org.springframework.samples.petclinic.customers.model.OwnerRepository;
import org.springframework.samples.petclinic.customers.web.mapper.OwnerEntityMapper;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.BDDMockito.given;
import static org.mockito.ArgumentMatchers.any;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Tests for OwnerResource CRUD operations.
 */
@WebMvcTest(OwnerResource.class)
@ActiveProfiles("test")
class OwnerResourceTest {

    @Autowired
    MockMvc mvc;

    @MockitoBean
    OwnerRepository ownerRepository;

    @MockitoBean
    OwnerEntityMapper ownerEntityMapper;

    @Test
    void shouldGetOwnerById() throws Exception {
        Owner owner = new Owner();
        owner.setId(1);
        owner.setFirstName("John");
        owner.setLastName("Doe");
        given(ownerRepository.findById(1)).willReturn(java.util.Optional.of(owner));

        mvc.perform(get("/owners/1").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.firstName").value("John"));
    }

    @Test
    void shouldCreateOwner() throws Exception {
        Owner owner = new Owner();
        owner.setId(2);
        given(ownerEntityMapper.map(any(Owner.class), any())).willReturn(owner);
        given(ownerRepository.save(any(Owner.class))).willReturn(owner);

        String json = "{\"firstName\":\"Jane\",\"lastName\":\"Smith\",\"address\":\"123 St\",\"city\":\"Town\",\"telephone\":\"123456789\"}";
        mvc.perform(post("/owners").contentType(MediaType.APPLICATION_JSON).content(json))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(2));
    }

    @Test
    void shouldDeleteOwner() throws Exception {
        mvc.perform(delete("/owners/3"))
                .andExpect(status().isNoContent());
    }
}
