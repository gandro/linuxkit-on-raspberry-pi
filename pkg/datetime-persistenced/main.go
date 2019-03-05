package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func load(file string) error {
	data, err := ioutil.ReadFile(file)
	if err != nil {
		return err
	}

	datetime, err := time.Parse(time.RFC3339, string(data))
	if err != nil {
		return err
	}

	// omit usecs, since RFC3339 does not contain them
	tv := syscall.Timeval{
		Sec: datetime.Unix(),
	}
	return syscall.Settimeofday(&tv)
}

func storeOnce(file string) error {
	data := []byte(time.Now().Format(time.RFC3339))
	return ioutil.WriteFile(file, data, 0644)
}

func store(file string, interval time.Duration) error {
	// stop on termination signals
	terminate := make(chan os.Signal, 1)
	signal.Notify(terminate, syscall.SIGTERM)
	signal.Notify(terminate, syscall.SIGINT)

	// tick every interval
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

Loop:
	for {
		if err := storeOnce(file); err != nil {
			return err
		}

		select {
		case <-terminate:
			break Loop
		case <-ticker.C:
		}
	}

	return storeOnce(file)
}

func main() {
	interval := flag.Duration("interval", 10*time.Minute, "Persistence interval for storing the time")
	file := flag.String("file", "/etc/datetime-persistence.txt", "File used to store the time")

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s [options] [load|store]\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "Commands:\n")
		fmt.Fprintf(os.Stderr, "  load    Loads datetime from file and sets system time accordingly\n")
		fmt.Fprintf(os.Stderr, "  store   Stores system time to file on every interval\n")
		fmt.Fprintf(os.Stderr, "Options:\n")
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "Set -interval 0 to store time only once (one-shot mode).\n")
	}

	flag.Parse()
	var err error
	cmd := flag.Arg(0)
	switch cmd {
	case "load":
		err = load(*file)
	case "store":
		if *interval > 0 {
			err = store(*file, *interval)
		} else {
			err = storeOnce(*file)
		}
	default:
		fmt.Fprintf(os.Stderr, "invalid command: %q\n", cmd)
		flag.Usage()
		os.Exit(2)
	}

	if err != nil {
		log.Fatalf("fatal error occured: %s", err)
	}
}
