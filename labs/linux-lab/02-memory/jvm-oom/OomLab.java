import java.util.ArrayList;
import java.util.List;

/**
 * A worker thread allocates until the heap is full while the main thread keeps
 * printing a heartbeat. By default the OutOfMemoryError only kills the worker
 * thread, so the JVM (and the container) keeps running with a broken app.
 * Run it with -XX:+ExitOnOutOfMemoryError to make the JVM exit instead.
 */
public class OomLab {
  public static void main(String[] args) throws Exception {
    Thread worker = new Thread(() -> {
      List<byte[]> hog = new ArrayList<>();
      while (true) {
        hog.add(new byte[1024 * 1024]);
        if (hog.size() % 8 == 0) {
          System.out.println("allocator holds " + hog.size() + " MiB");
        }
        try {
          Thread.sleep(50);
        } catch (InterruptedException e) {
          return;
        }
      }
    }, "allocator");
    worker.start();

    long beat = 0;
    while (true) {
      System.out.println("main heartbeat " + beat++ + " allocatorAlive=" + worker.isAlive());
      Thread.sleep(2000);
    }
  }
}
