/*
 * Copyright 2002-2021 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.springframework.samples.petclinic.vets.web;

import java.util.List;

import org.springframework.cache.annotation.Cacheable;
import org.springframework.samples.petclinic.vets.model.Vet;
import org.springframework.samples.petclinic.vets.model.VetRepository;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.ResponseStatus;

/**
 * @author Juergen Hoeller
 * @author Mark Fisher
 * @author Ken Krebs
 * @author Arjen Poutsma
 * @author Maciej Szarlinski
 */
@RequestMapping("/vets")
@RestController
public class VetResource {

    private final VetRepository vetRepository;

    public VetResource(VetRepository vetRepository) {
        this.vetRepository = vetRepository;
    }

    @DeleteMapping("/{vetId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteVet(@PathVariable("vetId") int vetId) {
        vetRepository.deleteById(vetId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Vet createVet(@RequestBody Vet vet) {
        return vetRepository.save(vet);
    }

    @PutMapping("/{vetId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void updateVet(@PathVariable("vetId") int vetId, @RequestBody Vet vet) {
        Vet existing = vetRepository.findById(vetId)
                .orElseThrow(() -> new IllegalArgumentException("Vet " + vetId + " not found"));
        existing.setFirstName(vet.getFirstName());
        existing.setLastName(vet.getLastName());
        // specialties handling omitted for brevity
        vetRepository.save(existing);
    }

    @GetMapping
    @Cacheable("vets")
    public List<Vet> showResourcesVetList() {
        return vetRepository.findAll();
    }
}
