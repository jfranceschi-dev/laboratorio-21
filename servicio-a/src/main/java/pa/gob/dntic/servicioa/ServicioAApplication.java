package pa.gob.dntic.servicioa;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClient;

@SpringBootApplication
@RestController
public class ServicioAApplication {

    public static void main(String[] args) {
        SpringApplication.run(ServicioAApplication.class, args);
    }

    // La URL de B viene de la CONFIGURACIÓN (variable de entorno), no del código.
    private final String urlB;
    private final RestClient rest = RestClient.create();

    public ServicioAApplication(@Value("${servicio.b.url}") String urlB) { this.urlB = urlB; }

    @GetMapping("/consulta")
    public String consulta() {
        String dato = rest.get().uri(urlB).retrieve().body(String.class);   // llamada REST a B
        return "El dato de B es: " + dato;
    }
}