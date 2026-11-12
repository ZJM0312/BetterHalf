package com.betterhalf.couple.domain;

import com.betterhalf.common.domain.BaseEntity;
import com.betterhalf.common.domain.CoupleInfo;
import com.betterhalf.common.domain.Visibility;
import jakarta.persistence.*;

import java.util.UUID;

@Entity
@Table(name = "couples", indexes = {
    @Index(name = "idx_couples_visibility", columnList = "visibility")
})
public class Couple extends BaseEntity implements CoupleInfo {
    
    @Column(nullable = false)
    private String name;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Visibility visibility = Visibility.PRIVATE;
    
    public String getName() {
        return name;
    }
    
    public void setName(String name) {
        this.name = name;
    }
    
    public Visibility getVisibility() {
        return visibility;
    }
    
    public void setVisibility(Visibility visibility) {
        this.visibility = visibility;
    }
}
