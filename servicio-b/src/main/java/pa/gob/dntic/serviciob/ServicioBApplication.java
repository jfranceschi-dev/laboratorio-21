package pa.gob.dntic.serviciob;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class ServicioBApplication {

    public static void main(String[] args) {
        SpringApplication.run(ServicioBApplication.class, args);
    }

    @GetMapping("/dato")
    public String dato() { return "dato-desde-B"; }
}